-- Extrait canonique du catalogue installé le 30/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "geolocalisation";
--
-- Name: SCHEMA geolocalisation; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA geolocalisation IS 'Référentiel hiérarchique des territoires, sites, populations et indicateurs de couverture géographique.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Niveau_0; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_0" (
    "ID_Niveau_0" integer CONSTRAINT "T_Niveau_0_ID_Niveau_0_not_null" NOT NULL,
    "NomNiveau_0" character varying(255),
    "CodeNiveau_0" character varying(10),
    "geometryNiveau_0" text,
    iso character varying(10),
    "uidSNIS" text
);

--
-- Name: TABLE "T_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_0" IS 'Unités géographiques de niveau 0 : identité et géométrie textuelle. Niveau racine de la hiérarchie.';

--
-- Name: COLUMN "T_Niveau_0"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_0"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0.';

--
-- Name: COLUMN "T_Niveau_0"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_0"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0.';

--
-- Name: COLUMN "T_Niveau_0"."CodeNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_0"."CodeNiveau_0" IS 'Code de référence de l’unité géographique de niveau 0.';

--
-- Name: COLUMN "T_Niveau_0"."geometryNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_0"."geometryNiveau_0" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 0.';

--
-- Name: CONSTRAINT "T_Niveau_0_ID_Niveau_0_not_null" ON "T_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_0_ID_Niveau_0_not_null" ON geolocalisation."T_Niveau_0" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_0". Définition : NOT NULL "ID_Niveau_0".';

--
-- Name: T_Niveau_0_ID_Niveau_0_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_0" ALTER COLUMN "ID_Niveau_0" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_0_ID_Niveau_0_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Niveau_0_ID_Niveau_0_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_0_ID_Niveau_0_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_0"."ID_Niveau_0". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Niveau_1; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_1" (
    "ID_Niveau_1" integer CONSTRAINT "T_Niveau_1_ID_Niveau_1_not_null" NOT NULL,
    "ID_Niveau_0_Fk" integer,
    "ID_Niveau_1_Old_Fk" integer,
    "NomNiveau_1" character varying(255),
    "Alt1_Niveau_1" character varying(255),
    "Alt2_Niveau_1" character varying(255),
    "AbreNiveau_1" character varying(255),
    "CodeSNIS" character varying(255),
    "CodeNiveau_1" character varying(255),
    "PopulationNiveau_1" numeric(12,0),
    "geometryNiveau_1" text,
    "surfaceNiveau_1" character varying(255),
    "timezoneNiveau_1" character varying(255),
    "wikidataNiveau_1" text,
    "EtenduNiveau_1" text,
    "ObsNiveau_1" text,
    "FusionNiveau_1" boolean,
    "VisibleNiveau_1" boolean DEFAULT true CONSTRAINT "T_Niveau_1_VisibleNiveau_1_not_null" NOT NULL,
    "VisibleNiveau_5" boolean DEFAULT true CONSTRAINT "T_Niveau_1_VisibleNiveau_5_not_null" NOT NULL,
    "LatitudeNiveau_1" numeric(9,6),
    "LongitudeNiveau_1" numeric(9,6),
    prov_uid text,
    "uidSNIS" text
);

--
-- Name: TABLE "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_1" IS 'Unités géographiques de niveau 1 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';

--
-- Name: COLUMN "T_Niveau_1"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."ID_Niveau_0_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."ID_Niveau_0_Fk" IS 'Unité géographique de rattachement de niveau 0. Relation imposée : FOREIGN KEY ("ID_Niveau_0_Fk") REFERENCES geolocalisation."T_Niveau_0"("ID_Niveau_0") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_1"."ID_Niveau_1_Old_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."ID_Niveau_1_Old_Fk" IS 'Unité géographique de rattachement de niveau 1_Old. Relation imposée : FOREIGN KEY ("ID_Niveau_1_Old_Fk") REFERENCES geolocalisation."T_Niveau_1_Old"("ID_Niveau_1_Old") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_1"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."Alt1_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."Alt1_Niveau_1" IS 'Première appellation alternative de l’unité de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."Alt2_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."Alt2_Niveau_1" IS 'Deuxième appellation alternative de l’unité de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."AbreNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."AbreNiveau_1" IS 'Abréviation de l’unité géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."CodeSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."CodeSNIS" IS 'Code SNIS enregistré pour l’unité géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."CodeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."CodeNiveau_1" IS 'Code de référence de l’unité géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."PopulationNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."PopulationNiveau_1" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."geometryNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."geometryNiveau_1" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."surfaceNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."surfaceNiveau_1" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."timezoneNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."timezoneNiveau_1" IS 'Fuseau horaire déclaré pour l’unité de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."wikidataNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."wikidataNiveau_1" IS 'Référence Wikidata déclarée pour l’unité de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."EtenduNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."EtenduNiveau_1" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."ObsNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."ObsNiveau_1" IS 'Observations sur l’unité géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."FusionNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."FusionNiveau_1" IS 'Indicateur de fusion enregistré pour l’unité de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."VisibleNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."VisibleNiveau_1" IS 'Indicateur de visibilité pour le niveau géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."VisibleNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_1"."LatitudeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."LatitudeNiveau_1" IS 'Latitude enregistrée pour l’unité géographique de niveau 1.';

--
-- Name: COLUMN "T_Niveau_1"."LongitudeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."LongitudeNiveau_1" IS 'Longitude enregistrée pour l’unité géographique de niveau 1.';

--
-- Name: CONSTRAINT "T_Niveau_1_ID_Niveau_1_not_null" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_ID_Niveau_1_not_null" ON geolocalisation."T_Niveau_1" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_1". Définition : NOT NULL "ID_Niveau_1".';

--
-- Name: CONSTRAINT "T_Niveau_1_VisibleNiveau_1_not_null" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_VisibleNiveau_1_not_null" ON geolocalisation."T_Niveau_1" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_1". Définition : NOT NULL "VisibleNiveau_1".';

--
-- Name: CONSTRAINT "T_Niveau_1_VisibleNiveau_5_not_null" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_VisibleNiveau_5_not_null" ON geolocalisation."T_Niveau_1" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_1". Définition : NOT NULL "VisibleNiveau_5".';

--
-- Name: T_Niveau_1_ID_Niveau_1_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_1" ALTER COLUMN "ID_Niveau_1" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_1_ID_Niveau_1_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Niveau_1_ID_Niveau_1_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_1_ID_Niveau_1_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_1"."ID_Niveau_1". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Niveau_1_Old; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_1_Old" (
    "ID_Niveau_1_Old" integer CONSTRAINT "T_Niveau_1_Old_ID_Niveau_1_Old_not_null" NOT NULL,
    "NomNiveau_1_Old" character varying(255),
    "geometryNiveau_1_Old" text,
    "surfaceNiveau_1_Old" character varying(255)
);

--
-- Name: TABLE "T_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_1_Old" IS 'Anciennes unités géographiques de niveau 1, conservées pour les correspondances historiques avec le découpage courant.';

--
-- Name: COLUMN "T_Niveau_1_Old"."ID_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1_Old"."ID_Niveau_1_Old" IS 'Identifiant de l’unité géographique de niveau 1 historique.';

--
-- Name: COLUMN "T_Niveau_1_Old"."NomNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1_Old"."NomNiveau_1_Old" IS 'Nom de l’unité géographique de niveau 1 historique.';

--
-- Name: COLUMN "T_Niveau_1_Old"."geometryNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1_Old"."geometryNiveau_1_Old" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 1 historique.';

--
-- Name: COLUMN "T_Niveau_1_Old"."surfaceNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1_Old"."surfaceNiveau_1_Old" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 1 historique.';

--
-- Name: CONSTRAINT "T_Niveau_1_Old_ID_Niveau_1_Old_not_null" ON "T_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_Old_ID_Niveau_1_Old_not_null" ON geolocalisation."T_Niveau_1_Old" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_1_Old". Définition : NOT NULL "ID_Niveau_1_Old".';

--
-- Name: T_Niveau_1_Old_ID_Niveau_1_Old_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_1_Old" ALTER COLUMN "ID_Niveau_1_Old" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_1_Old_ID_Niveau_1_Old_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Niveau_1_Old_ID_Niveau_1_Old_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_1_Old_ID_Niveau_1_Old_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_1_Old"."ID_Niveau_1_Old". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Niveau_2; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_2" (
    "ID_Niveau_2" integer CONSTRAINT "T_Niveau_2_ID_Niveau_2_not_null" NOT NULL,
    "ID_Niveau_1_FK" integer,
    "ID_TypeNiveau_2_Fk" integer,
    "NomNiveau_2" character varying(255),
    "Alt1_NomNiveau_2" character varying(255),
    "AbreNiveau_2" character varying(255),
    "CodeNiveau_2" character varying(255),
    "PopulationNiveau_2" numeric(12,0),
    "geometryNiveau_2" text,
    "surfaceNiveau_2" character varying(255),
    "EtenduNiveau_2" text,
    "ObsNiveau_2" text,
    "ID_StatutNiveau_2" integer,
    "ID_StatusDeploiFk" integer,
    "KmDPSANT" numeric(10,2),
    "ID_VoieAccesDPSANTFk" integer,
    "SelectNiveau_2" boolean,
    "LatitudeNiveau_2" numeric(9,6),
    "LongitudeNiveau_2" numeric(9,6),
    "AltitudeNiveau_2" numeric(10,2),
    iso text,
    "uidSNIS" text
);

--
-- Name: TABLE "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_2" IS 'Unités géographiques de niveau 2 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';

--
-- Name: COLUMN "T_Niveau_2"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."ID_Niveau_1_FK"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_Niveau_1_FK" IS 'Unité géographique de rattachement de niveau 1. Relation imposée : FOREIGN KEY ("ID_Niveau_1_FK") REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_2"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';

--
-- Name: COLUMN "T_Niveau_2"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."Alt1_NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."Alt1_NomNiveau_2" IS 'Appellation alternative de l’unité de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."AbreNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."AbreNiveau_2" IS 'Abréviation de l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."CodeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."CodeNiveau_2" IS 'Code de référence de l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."PopulationNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."PopulationNiveau_2" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."geometryNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."geometryNiveau_2" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."surfaceNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."surfaceNiveau_2" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."EtenduNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."EtenduNiveau_2" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."ObsNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ObsNiveau_2" IS 'Observations sur l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."ID_StatutNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_StatutNiveau_2" IS 'Statut de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_StatutNiveau_2") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_2"."ID_StatusDeploiFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_StatusDeploiFk" IS 'Statut de déploiement enregistré pour l’unité de niveau 2. Relation imposée : FOREIGN KEY ("ID_StatusDeploiFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_2"."KmDPSANT"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."KmDPSANT" IS 'Distance enregistrée entre la DPS et l’antenne, en kilomètres.';

--
-- Name: COLUMN "T_Niveau_2"."ID_VoieAccesDPSANTFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_VoieAccesDPSANTFk" IS 'Voie d’accès entre la DPS et l’antenne. Relation imposée : FOREIGN KEY ("ID_VoieAccesDPSANTFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_2"."SelectNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."SelectNiveau_2" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."LatitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."LatitudeNiveau_2" IS 'Latitude enregistrée pour l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."LongitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."LongitudeNiveau_2" IS 'Longitude enregistrée pour l’unité géographique de niveau 2.';

--
-- Name: COLUMN "T_Niveau_2"."AltitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."AltitudeNiveau_2" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 2.';

--
-- Name: CONSTRAINT "T_Niveau_2_ID_Niveau_2_not_null" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_2_ID_Niveau_2_not_null" ON geolocalisation."T_Niveau_2" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_2". Définition : NOT NULL "ID_Niveau_2".';

--
-- Name: T_Niveau_2_ID_Niveau_2_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_2" ALTER COLUMN "ID_Niveau_2" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_2_ID_Niveau_2_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Niveau_2_ID_Niveau_2_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_2_ID_Niveau_2_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_2"."ID_Niveau_2". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Niveau_3; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_3" (
    "ID_Niveau_3" integer CONSTRAINT "T_Niveau_3_ID_Niveau_3_not_null" NOT NULL,
    "ID_Niveau_2_FK" integer,
    "ID_TypeNiveau_2_Fk" integer,
    "NomNiveau_3" character varying(255),
    "Alt_Niveau_3" character varying(255),
    "surfaceNiveau_3" character varying(255),
    "geometryNiveau_3" text,
    "AbreNiveau_3" character varying(255),
    "CodeNiveau_3" character varying(255),
    "PopulationNiveau_3" numeric(12,0),
    "EtenduNiveau_3" text,
    "ObsNiveau_3" text,
    "ID_StatutNiveau_3_Fk" integer,
    "ID_StatutDeploieFk" integer,
    "KmAntenneBCZS" numeric(100,7),
    "ID_VoieAccesANTBCZFk" integer,
    "KmDPSBCZS" numeric(100,7),
    "ID_VoieAccesDPSBCZFk" integer,
    "SelectNiveau_3" boolean,
    "LatitudeNiveau_3" numeric(13,5),
    "LongitudeNiveau_3" numeric(13,5),
    "AltitudeNiveau_3" numeric(10,7),
    iso text,
    "uidSNIS" text
);

--
-- Name: TABLE "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_3" IS 'Unités géographiques de niveau 3 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';

--
-- Name: COLUMN "T_Niveau_3"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."ID_Niveau_2_FK"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_Niveau_2_FK" IS 'Unité géographique de rattachement de niveau 2. Relation imposée : FOREIGN KEY ("ID_Niveau_2_FK") REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_3"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE NOT VALID.';

--
-- Name: COLUMN "T_Niveau_3"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."Alt_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."Alt_Niveau_3" IS 'Appellation alternative de l’unité de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."surfaceNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."surfaceNiveau_3" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."geometryNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."geometryNiveau_3" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."AbreNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."AbreNiveau_3" IS 'Abréviation de l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."CodeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."CodeNiveau_3" IS 'Code de référence de l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."PopulationNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."PopulationNiveau_3" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."EtenduNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."EtenduNiveau_3" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."ObsNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ObsNiveau_3" IS 'Observations sur l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."ID_StatutNiveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_StatutNiveau_3_Fk" IS 'Statut de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_StatutNiveau_3_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_3"."ID_StatutDeploieFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_StatutDeploieFk" IS 'Statut de déploiement enregistré pour l’unité de niveau 3. Relation imposée : FOREIGN KEY ("ID_StatutDeploieFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_3"."KmAntenneBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."KmAntenneBCZS" IS 'Distance enregistrée entre l’antenne et le bureau central de zone de santé, en kilomètres.';

--
-- Name: COLUMN "T_Niveau_3"."ID_VoieAccesANTBCZFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_VoieAccesANTBCZFk" IS 'Voie d’accès entre l’antenne et le bureau central de zone de santé. Relation imposée : FOREIGN KEY ("ID_VoieAccesANTBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_3"."KmDPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."KmDPSBCZS" IS 'Distance enregistrée entre la DPS et le bureau central de zone de santé, en kilomètres.';

--
-- Name: COLUMN "T_Niveau_3"."ID_VoieAccesDPSBCZFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_VoieAccesDPSBCZFk" IS 'Voie d’accès entre la DPS et le bureau central de zone de santé. Relation imposée : FOREIGN KEY ("ID_VoieAccesDPSBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_3"."SelectNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."SelectNiveau_3" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."LatitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."LatitudeNiveau_3" IS 'Latitude enregistrée pour l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."LongitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."LongitudeNiveau_3" IS 'Longitude enregistrée pour l’unité géographique de niveau 3.';

--
-- Name: COLUMN "T_Niveau_3"."AltitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."AltitudeNiveau_3" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 3.';

--
-- Name: CONSTRAINT "T_Niveau_3_ID_Niveau_3_not_null" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_3_ID_Niveau_3_not_null" ON geolocalisation."T_Niveau_3" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_3". Définition : NOT NULL "ID_Niveau_3".';

--
-- Name: T_Niveau_3_ID_Niveau_3_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_3" ALTER COLUMN "ID_Niveau_3" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_3_ID_Niveau_3_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Niveau_3_ID_Niveau_3_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_3_ID_Niveau_3_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_3"."ID_Niveau_3". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Niveau_4; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_4" (
    "ID_Niveau_4" integer CONSTRAINT "T_Niveau_4_ID_Niveau_4_not_null" NOT NULL,
    "ID_Niveau_3_Fk" integer,
    "ID_TypeNiveau_4_Fk" integer,
    "NomNiveau_4" character varying(255),
    "AbreNiveau_4" character varying(255),
    "CodeNiveau_4" character varying(255),
    "surfaceNiveau_4" character varying(255),
    "geometryNiveau_4" text,
    "ID_DispoReseauNiveau_4" integer,
    "ID_VoieAccesZsASFk" integer,
    "ID_StatutNiveau_4" integer,
    "ID_StatutDeploiementFk" integer,
    "ObsNiveau_4" text,
    "SelectNiveau_4" boolean,
    "LatitudeNiveau_4" numeric(13,6),
    "LongitudeNiveau_4" numeric(13,6),
    "AltitudeNiveau_4" numeric(10,2),
    "PopulationNiveau_4" numeric(12,0),
    "KmZoneSanteAS" numeric(10,2),
    iso text,
    "uidSNIS" text
);

--
-- Name: TABLE "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_4" IS 'Unités géographiques de niveau 4 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';

--
-- Name: COLUMN "T_Niveau_4"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_Niveau_4" IS 'Identifiant de l’unité géographique de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_Niveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Relation imposée : FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_4"."ID_TypeNiveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_TypeNiveau_4_Fk" IS 'Type de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_TypeNiveau_4_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE NOT VALID.';

--
-- Name: COLUMN "T_Niveau_4"."NomNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."NomNiveau_4" IS 'Nom de l’unité géographique de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."AbreNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."AbreNiveau_4" IS 'Abréviation de l’unité géographique de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."CodeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."CodeNiveau_4" IS 'Code de référence de l’unité géographique de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."surfaceNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."surfaceNiveau_4" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."geometryNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."geometryNiveau_4" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."ID_DispoReseauNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_DispoReseauNiveau_4" IS 'Disponibilité du réseau déclarée pour l’unité géographique, dans le référentiel. Relation imposée : FOREIGN KEY ("ID_DispoReseauNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_4"."ID_VoieAccesZsASFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_VoieAccesZsASFk" IS 'Voie d’accès entre la zone de santé et l’aire de santé. Relation imposée : FOREIGN KEY ("ID_VoieAccesZsASFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_4"."ID_StatutNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_StatutNiveau_4" IS 'Statut de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_StatutNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_4"."ID_StatutDeploiementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_StatutDeploiementFk" IS 'Statut de déploiement enregistré pour l’unité géographique. Relation imposée : FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_4"."ObsNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ObsNiveau_4" IS 'Observations sur l’unité géographique de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."SelectNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."SelectNiveau_4" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."LatitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."LatitudeNiveau_4" IS 'Latitude enregistrée pour l’unité géographique de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."LongitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."LongitudeNiveau_4" IS 'Longitude enregistrée pour l’unité géographique de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."AltitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."AltitudeNiveau_4" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."PopulationNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."PopulationNiveau_4" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 4.';

--
-- Name: COLUMN "T_Niveau_4"."KmZoneSanteAS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."KmZoneSanteAS" IS 'Distance enregistrée entre la zone de santé et l’aire de santé, en kilomètres.';

--
-- Name: CONSTRAINT "T_Niveau_4_ID_Niveau_4_not_null" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_4_ID_Niveau_4_not_null" ON geolocalisation."T_Niveau_4" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_4". Définition : NOT NULL "ID_Niveau_4".';

--
-- Name: T_Niveau_4_ID_Niveau_4_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_4" ALTER COLUMN "ID_Niveau_4" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_4_ID_Niveau_4_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Niveau_4_ID_Niveau_4_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_4_ID_Niveau_4_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_4"."ID_Niveau_4". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Niveau_5; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_5" (
    "ID_Niveau_5" integer CONSTRAINT "T_Niveau_5_ID_Niveau_5_not_null" NOT NULL,
    "ID_Niveau_4_Fk" integer,
    "ID_Niveau_3_Fk" integer,
    "ID_TypeNiveau_5_Fk" integer,
    "NomNiveau_5" character varying(255),
    "AbreNiveau_5" character varying(255),
    "CodeNiveau_5" character varying(255),
    "PopulationNiveau_5" numeric(12,0),
    "surfaceNiveau_5" character varying(255),
    "geometryNiveau_5" text,
    "ID_DispoReseauNiveau_5" integer,
    "ID_VoieAccesZsSiteFk" integer,
    "ID_StatutNiveau_5" integer,
    "ID_StatutDeploiementFk" integer,
    "ObsNiveau_5" text,
    "SelectNiveau_5" boolean,
    "ID_TypeToitFk" integer,
    "KmZoneSanteNiveau_5" numeric(12,2),
    "LatitudeNiveau_5" numeric(12,6),
    "LongitudeNiveau_5" numeric(12,6),
    "AltitudeNiveau_5" numeric(12,2),
    iso text,
    "uidSNIS" text
);

--
-- Name: TABLE "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_5" IS 'Unités géographiques de niveau 5 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';

--
-- Name: COLUMN "T_Niveau_5"."ID_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_Niveau_5" IS 'Identifiant de l’unité géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."ID_Niveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_Niveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Relation imposée : FOREIGN KEY ("ID_Niveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_5"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_Niveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Relation imposée : FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_5"."ID_TypeNiveau_5_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_TypeNiveau_5_Fk" IS 'Type de structure ou site : identifiant de T_Generique. La famille des nouveaux choix est résolue par le référencement physique commun ; les valeurs historiques inchangées sont conservées.';

--
-- Name: COLUMN "T_Niveau_5"."NomNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."NomNiveau_5" IS 'Nom de l’unité géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."AbreNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."AbreNiveau_5" IS 'Abréviation de l’unité géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."CodeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."CodeNiveau_5" IS 'Code de référence de l’unité géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."PopulationNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."PopulationNiveau_5" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."surfaceNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."surfaceNiveau_5" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."geometryNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."geometryNiveau_5" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."ID_DispoReseauNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_DispoReseauNiveau_5" IS 'Disponibilité du réseau déclarée pour l’unité géographique, dans le référentiel. Relation imposée : FOREIGN KEY ("ID_DispoReseauNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_5"."ID_VoieAccesZsSiteFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_VoieAccesZsSiteFk" IS 'Voie d’accès entre la zone de santé et le site. Relation imposée : FOREIGN KEY ("ID_VoieAccesZsSiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_5"."ID_StatutNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_StatutNiveau_5" IS 'Statut de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_StatutNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_5"."ID_StatutDeploiementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_StatutDeploiementFk" IS 'Statut de déploiement enregistré pour l’unité géographique. Relation imposée : FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_5"."ObsNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ObsNiveau_5" IS 'Observations sur l’unité géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."SelectNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."SelectNiveau_5" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."ID_TypeToitFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_TypeToitFk" IS 'Type de toiture du site, issu du référentiel. Relation imposée : FOREIGN KEY ("ID_TypeToitFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Niveau_5"."KmZoneSanteNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."KmZoneSanteNiveau_5" IS 'Distance enregistrée entre la zone de santé et le site, en kilomètres.';

--
-- Name: COLUMN "T_Niveau_5"."LatitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."LatitudeNiveau_5" IS 'Latitude enregistrée pour l’unité géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."LongitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."LongitudeNiveau_5" IS 'Longitude enregistrée pour l’unité géographique de niveau 5.';

--
-- Name: COLUMN "T_Niveau_5"."AltitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."AltitudeNiveau_5" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 5.';

--
-- Name: CONSTRAINT "T_Niveau_5_ID_Niveau_5_not_null" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_5_ID_Niveau_5_not_null" ON geolocalisation."T_Niveau_5" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_5". Définition : NOT NULL "ID_Niveau_5".';

--
-- Name: T_Niveau_5_ID_Niveau_5_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_5" ALTER COLUMN "ID_Niveau_5" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_5_ID_Niveau_5_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Niveau_5_ID_Niveau_5_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_5_ID_Niveau_5_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_5"."ID_Niveau_5". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Niveau_0 T_Niveau_0_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_0"
    ADD CONSTRAINT "T_Niveau_0_pkey" PRIMARY KEY ("ID_Niveau_0");

--
-- Name: CONSTRAINT "T_Niveau_0_pkey" ON "T_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_0_pkey" ON geolocalisation."T_Niveau_0" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_0". Définition : PRIMARY KEY ("ID_Niveau_0").';

--
-- Name: T_Niveau_1_Old T_Niveau_1_Old_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_1_Old"
    ADD CONSTRAINT "T_Niveau_1_Old_pkey" PRIMARY KEY ("ID_Niveau_1_Old");

--
-- Name: CONSTRAINT "T_Niveau_1_Old_pkey" ON "T_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_Old_pkey" ON geolocalisation."T_Niveau_1_Old" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_1_Old". Définition : PRIMARY KEY ("ID_Niveau_1_Old").';

--
-- Name: T_Niveau_1 T_Niveau_1_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_1"
    ADD CONSTRAINT "T_Niveau_1_pkey" PRIMARY KEY ("ID_Niveau_1");

--
-- Name: CONSTRAINT "T_Niveau_1_pkey" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_pkey" ON geolocalisation."T_Niveau_1" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_1". Définition : PRIMARY KEY ("ID_Niveau_1").';

--
-- Name: T_Niveau_2 T_Niveau_2_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "T_Niveau_2_pkey" PRIMARY KEY ("ID_Niveau_2");

--
-- Name: CONSTRAINT "T_Niveau_2_pkey" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_2_pkey" ON geolocalisation."T_Niveau_2" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_2". Définition : PRIMARY KEY ("ID_Niveau_2").';

--
-- Name: T_Niveau_3 T_Niveau_3_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "T_Niveau_3_pkey" PRIMARY KEY ("ID_Niveau_3");

--
-- Name: CONSTRAINT "T_Niveau_3_pkey" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_3_pkey" ON geolocalisation."T_Niveau_3" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_3". Définition : PRIMARY KEY ("ID_Niveau_3").';

--
-- Name: T_Niveau_4 T_Niveau_4_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "T_Niveau_4_pkey" PRIMARY KEY ("ID_Niveau_4");

--
-- Name: CONSTRAINT "T_Niveau_4_pkey" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_4_pkey" ON geolocalisation."T_Niveau_4" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_4". Définition : PRIMARY KEY ("ID_Niveau_4").';

--
-- Name: T_Niveau_5 T_Niveau_5_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "T_Niveau_5_pkey" PRIMARY KEY ("ID_Niveau_5");

--
-- Name: CONSTRAINT "T_Niveau_5_pkey" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_5_pkey" ON geolocalisation."T_Niveau_5" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_5". Définition : PRIMARY KEY ("ID_Niveau_5").';

--
-- Name: INDEX "T_Niveau_0_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_0_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_0". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_0_pkey" ON geolocalisation."T_Niveau_0" USING btree ("ID_Niveau_0").';

--
-- Name: T_Niveau_1_ID_Niveau_0_Fk_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_1_ID_Niveau_0_Fk_idx" ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_0_Fk");

--
-- Name: INDEX "T_Niveau_1_ID_Niveau_0_Fk_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_1_ID_Niveau_0_Fk_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_1". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_1_ID_Niveau_0_Fk_idx" ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_0_Fk").';

--
-- Name: INDEX "T_Niveau_1_Old_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_1_Old_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_1_Old". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_1_Old_pkey" ON geolocalisation."T_Niveau_1_Old" USING btree ("ID_Niveau_1_Old").';

--
-- Name: INDEX "T_Niveau_1_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_1_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_1". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_1_pkey" ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_1").';

--
-- Name: T_Niveau_2_ID_Niveau_1_FK_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_2_ID_Niveau_1_FK_idx" ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_1_FK");

--
-- Name: INDEX "T_Niveau_2_ID_Niveau_1_FK_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_2_ID_Niveau_1_FK_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_2_ID_Niveau_1_FK_idx" ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_1_FK").';

--
-- Name: INDEX "T_Niveau_2_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_2_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_2_pkey" ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_2").';

--
-- Name: T_Niveau_3_ID_Niveau_2_FK_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_3_ID_Niveau_2_FK_idx" ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_2_FK");

--
-- Name: INDEX "T_Niveau_3_ID_Niveau_2_FK_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_3_ID_Niveau_2_FK_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_3_ID_Niveau_2_FK_idx" ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_2_FK").';

--
-- Name: INDEX "T_Niveau_3_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_3_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_3_pkey" ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_3").';

--
-- Name: T_Niveau_4_ID_Niveau_3_Fk_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_4_ID_Niveau_3_Fk_idx" ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_3_Fk");

--
-- Name: INDEX "T_Niveau_4_ID_Niveau_3_Fk_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_4_ID_Niveau_3_Fk_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_4_ID_Niveau_3_Fk_idx" ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_3_Fk").';

--
-- Name: INDEX "T_Niveau_4_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_4_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_4_pkey" ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_4").';

--
-- Name: T_Niveau_5_ID_Niveau_3_Fk_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_5_ID_Niveau_3_Fk_idx" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_3_Fk");

--
-- Name: INDEX "T_Niveau_5_ID_Niveau_3_Fk_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_5_ID_Niveau_3_Fk_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_5_ID_Niveau_3_Fk_idx" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_3_Fk").';

--
-- Name: T_Niveau_5_ID_Niveau_4_Fk_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_5_ID_Niveau_4_Fk_idx" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_4_Fk");

--
-- Name: INDEX "T_Niveau_5_ID_Niveau_4_Fk_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_5_ID_Niveau_4_Fk_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_5_ID_Niveau_4_Fk_idx" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_4_Fk").';

--
-- Name: INDEX "T_Niveau_5_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_5_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_5_pkey" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_5").';

--
-- Name: idx_n1_id_niveau0_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n1_id_niveau0_fk ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_0_Fk");

--
-- Name: INDEX idx_n1_id_niveau0_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n1_id_niveau0_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_1". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n1_id_niveau0_fk ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_0_Fk").';

--
-- Name: idx_n1_id_niveau1_old_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n1_id_niveau1_old_fk ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_1_Old_Fk");

--
-- Name: INDEX idx_n1_id_niveau1_old_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n1_id_niveau1_old_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_1". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n1_id_niveau1_old_fk ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_1_Old_Fk").';

--
-- Name: idx_n2_id_niveau1_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_niveau1_fk ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_1_FK");

--
-- Name: INDEX idx_n2_id_niveau1_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_niveau1_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_niveau1_fk ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_1_FK").';

--
-- Name: idx_n2_id_statusdeploi_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_statusdeploi_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_StatusDeploiFk");

--
-- Name: INDEX idx_n2_id_statusdeploi_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_statusdeploi_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_statusdeploi_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_StatusDeploiFk").';

--
-- Name: idx_n2_id_statutniveau2_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_statutniveau2_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_StatutNiveau_2");

--
-- Name: INDEX idx_n2_id_statutniveau2_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_statutniveau2_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_statutniveau2_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_StatutNiveau_2").';

--
-- Name: idx_n2_id_typeniveau2_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_typeniveau2_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_TypeNiveau_2_Fk");

--
-- Name: INDEX idx_n2_id_typeniveau2_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_typeniveau2_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_typeniveau2_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_TypeNiveau_2_Fk").';

--
-- Name: idx_n2_id_voieaccesdpsant_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_voieaccesdpsant_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_VoieAccesDPSANTFk");

--
-- Name: INDEX idx_n2_id_voieaccesdpsant_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_voieaccesdpsant_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_voieaccesdpsant_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_VoieAccesDPSANTFk").';

--
-- Name: idx_n3_id_niveau2_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_niveau2_fk ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_2_FK");

--
-- Name: INDEX idx_n3_id_niveau2_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_niveau2_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_niveau2_fk ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_2_FK").';

--
-- Name: idx_n3_id_statutdeploie_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_statutdeploie_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_StatutDeploieFk");

--
-- Name: INDEX idx_n3_id_statutdeploie_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_statutdeploie_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_statutdeploie_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_StatutDeploieFk").';

--
-- Name: idx_n3_id_statutniveau3_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_statutniveau3_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_StatutNiveau_3_Fk");

--
-- Name: INDEX idx_n3_id_statutniveau3_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_statutniveau3_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_statutniveau3_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_StatutNiveau_3_Fk").';

--
-- Name: idx_n3_id_typeniveau2_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_typeniveau2_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_TypeNiveau_2_Fk");

--
-- Name: INDEX idx_n3_id_typeniveau2_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_typeniveau2_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_typeniveau2_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_TypeNiveau_2_Fk").';

--
-- Name: idx_n3_id_voieaccesantbcz_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_voieaccesantbcz_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_VoieAccesANTBCZFk");

--
-- Name: INDEX idx_n3_id_voieaccesantbcz_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_voieaccesantbcz_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_voieaccesantbcz_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_VoieAccesANTBCZFk").';

--
-- Name: idx_n3_id_voieaccesdpsbcz_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_voieaccesdpsbcz_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_VoieAccesDPSBCZFk");

--
-- Name: INDEX idx_n3_id_voieaccesdpsbcz_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_voieaccesdpsbcz_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_voieaccesdpsbcz_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_VoieAccesDPSBCZFk").';

--
-- Name: idx_n4_id_disporeseau_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_disporeseau_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_DispoReseauNiveau_4");

--
-- Name: INDEX idx_n4_id_disporeseau_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_disporeseau_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_disporeseau_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_DispoReseauNiveau_4").';

--
-- Name: idx_n4_id_niveau3_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_niveau3_fk ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_3_Fk");

--
-- Name: INDEX idx_n4_id_niveau3_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_niveau3_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_niveau3_fk ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_3_Fk").';

--
-- Name: idx_n4_id_statutdeploiement_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_statutdeploiement_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_StatutDeploiementFk");

--
-- Name: INDEX idx_n4_id_statutdeploiement_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_statutdeploiement_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_statutdeploiement_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_StatutDeploiementFk").';

--
-- Name: idx_n4_id_statutniveau4_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_statutniveau4_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_StatutNiveau_4");

--
-- Name: INDEX idx_n4_id_statutniveau4_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_statutniveau4_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_statutniveau4_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_StatutNiveau_4").';

--
-- Name: idx_n4_id_typeniveau4_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_typeniveau4_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_TypeNiveau_4_Fk");

--
-- Name: INDEX idx_n4_id_typeniveau4_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_typeniveau4_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_typeniveau4_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_TypeNiveau_4_Fk").';

--
-- Name: idx_n4_id_voieacceszsa_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_voieacceszsa_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_VoieAccesZsASFk");

--
-- Name: INDEX idx_n4_id_voieacceszsa_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_voieacceszsa_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_voieacceszsa_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_VoieAccesZsASFk").';

--
-- Name: idx_n5_id_disporeseau_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_disporeseau_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_DispoReseauNiveau_5");

--
-- Name: INDEX idx_n5_id_disporeseau_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_disporeseau_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_disporeseau_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_DispoReseauNiveau_5").';

--
-- Name: idx_n5_id_niveau4_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_niveau4_fk ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_4_Fk");

--
-- Name: INDEX idx_n5_id_niveau4_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_niveau4_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_niveau4_fk ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_4_Fk").';

--
-- Name: idx_n5_id_statutdeploiement_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_statutdeploiement_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_StatutDeploiementFk");

--
-- Name: INDEX idx_n5_id_statutdeploiement_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_statutdeploiement_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_statutdeploiement_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_StatutDeploiementFk").';

--
-- Name: idx_n5_id_statutniveau5_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_statutniveau5_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_StatutNiveau_5");

--
-- Name: INDEX idx_n5_id_statutniveau5_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_statutniveau5_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_statutniveau5_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_StatutNiveau_5").';

--
-- Name: idx_n5_id_typeniveau5_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_typeniveau5_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeNiveau_5_Fk");

--
-- Name: INDEX idx_n5_id_typeniveau5_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_typeniveau5_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_typeniveau5_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeNiveau_5_Fk").';

--
-- Name: idx_n5_id_typetoit_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_typetoit_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeToitFk");

--
-- Name: INDEX idx_n5_id_typetoit_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_typetoit_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_typetoit_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeToitFk").';

--
-- Name: idx_n5_id_voieaccessite_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_voieaccessite_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_VoieAccesZsSiteFk");

--
-- Name: INDEX idx_n5_id_voieaccessite_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_voieaccessite_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_voieaccessite_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_VoieAccesZsSiteFk").';

--
-- Name: T_Niveau_2 aa_reference_champ; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON geolocalisation."T_Niveau_2" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON geolocalisation."T_Niveau_2" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Niveau_3 aa_reference_champ; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON geolocalisation."T_Niveau_3" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON geolocalisation."T_Niveau_3" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Niveau_4 aa_reference_champ; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON geolocalisation."T_Niveau_4" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON geolocalisation."T_Niveau_4" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Niveau_5 aa_reference_champ; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON geolocalisation."T_Niveau_5" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON geolocalisation."T_Niveau_5" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Niveau_4 Fk_ID_DispoReseauNiveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_DispoReseauNiveau_4" FOREIGN KEY ("ID_DispoReseauNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_DispoReseauNiveau_4" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_DispoReseauNiveau_4" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_DispoReseauNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_5 Fk_ID_DispoReseauNiveau_5; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_DispoReseauNiveau_5" FOREIGN KEY ("ID_DispoReseauNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_DispoReseauNiveau_5" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_DispoReseauNiveau_5" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_DispoReseauNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_1 Fk_ID_Niveau_0; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_1"
    ADD CONSTRAINT "Fk_ID_Niveau_0" FOREIGN KEY ("ID_Niveau_0_Fk") REFERENCES geolocalisation."T_Niveau_0"("ID_Niveau_0") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_Niveau_0" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_0" ON geolocalisation."T_Niveau_1" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_1". Définition : FOREIGN KEY ("ID_Niveau_0_Fk") REFERENCES geolocalisation."T_Niveau_0"("ID_Niveau_0") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_2 Fk_ID_Niveau_1; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_Niveau_1" FOREIGN KEY ("ID_Niveau_1_FK") REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_Niveau_1" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_1" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_2". Définition : FOREIGN KEY ("ID_Niveau_1_FK") REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_1 Fk_ID_Niveau_1_Old; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_1"
    ADD CONSTRAINT "Fk_ID_Niveau_1_Old" FOREIGN KEY ("ID_Niveau_1_Old_Fk") REFERENCES geolocalisation."T_Niveau_1_Old"("ID_Niveau_1_Old") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_Niveau_1_Old" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_1_Old" ON geolocalisation."T_Niveau_1" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_1". Définition : FOREIGN KEY ("ID_Niveau_1_Old_Fk") REFERENCES geolocalisation."T_Niveau_1_Old"("ID_Niveau_1_Old") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_3 Fk_ID_Niveau_2; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_Niveau_2" FOREIGN KEY ("ID_Niveau_2_FK") REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_Niveau_2" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_2" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_Niveau_2_FK") REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_4 Fk_ID_Niveau_3; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_Niveau_3" FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_Niveau_3" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_3" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_5 Fk_ID_Niveau_3_N5; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_Niveau_3_N5" FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_Niveau_3_N5" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_3_N5" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_5 Fk_ID_Niveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_Niveau_4" FOREIGN KEY ("ID_Niveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_Niveau_4" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_4" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_Niveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_2 Fk_ID_StatusDeploiFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_StatusDeploiFk" FOREIGN KEY ("ID_StatusDeploiFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_StatusDeploiFk" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatusDeploiFk" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_2". Définition : FOREIGN KEY ("ID_StatusDeploiFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_3 Fk_ID_StatutDeploieFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_StatutDeploieFk" FOREIGN KEY ("ID_StatutDeploieFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_StatutDeploieFk" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutDeploieFk" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_StatutDeploieFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_4 Fk_ID_StatutDeploiementNiveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4" FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_5 Fk_ID_StatutDeploiementNiveau_5; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5" FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_2 Fk_ID_StatutNiveau_2; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_StatutNiveau_2" FOREIGN KEY ("ID_StatutNiveau_2") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_StatutNiveau_2" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutNiveau_2" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_2". Définition : FOREIGN KEY ("ID_StatutNiveau_2") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_3 Fk_ID_StatutNiveau_3; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_StatutNiveau_3" FOREIGN KEY ("ID_StatutNiveau_3_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_StatutNiveau_3" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutNiveau_3" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_StatutNiveau_3_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_4 Fk_ID_StatutNiveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_StatutNiveau_4" FOREIGN KEY ("ID_StatutNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_StatutNiveau_4" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutNiveau_4" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_StatutNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_5 Fk_ID_StatutNiveau_5; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_StatutNiveau_5" FOREIGN KEY ("ID_StatutNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_StatutNiveau_5" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutNiveau_5" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_StatutNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_2 Fk_ID_TypeNiveau_2; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_TypeNiveau_2" FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_TypeNiveau_2" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_2" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Niveau_3 Fk_ID_TypeNiveau_2; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_TypeNiveau_2" FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_TypeNiveau_2" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_2" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE';

--
-- Name: T_Niveau_4 Fk_ID_TypeNiveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_TypeNiveau_4" FOREIGN KEY ("ID_TypeNiveau_4_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_TypeNiveau_4" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_4" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_4_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE';

--
-- Name: T_Niveau_5 Fk_ID_TypeToitFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_TypeToitFk" FOREIGN KEY ("ID_TypeToitFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_TypeToitFk" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeToitFk" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_TypeToitFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_3 Fk_ID_VoieAccesANTBCZFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_VoieAccesANTBCZFk" FOREIGN KEY ("ID_VoieAccesANTBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_VoieAccesANTBCZFk" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesANTBCZFk" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_VoieAccesANTBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_2 Fk_ID_VoieAccesDPSANTFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_VoieAccesDPSANTFk" FOREIGN KEY ("ID_VoieAccesDPSANTFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_VoieAccesDPSANTFk" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesDPSANTFk" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_2". Définition : FOREIGN KEY ("ID_VoieAccesDPSANTFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_3 Fk_ID_VoieAccesDPSBCZFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk" FOREIGN KEY ("ID_VoieAccesDPSBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_VoieAccesDPSBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_4 Fk_ID_VoieAccesZsASFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_VoieAccesZsASFk" FOREIGN KEY ("ID_VoieAccesZsASFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_VoieAccesZsASFk" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesZsASFk" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_VoieAccesZsASFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Niveau_5 Fk_ID_VoieAccesZsSiteFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_VoieAccesZsSiteFk" FOREIGN KEY ("ID_VoieAccesZsSiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_VoieAccesZsSiteFk" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesZsSiteFk" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_VoieAccesZsSiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: ix_niveau5_type_reference; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX ix_niveau5_type_reference ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeNiveau_5_Fk");

--
-- Name: INDEX ix_niveau5_type_reference; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.ix_niveau5_type_reference IS 'Recherche, filtrage et contrôle des sites par valeur du référentiel partagé.';

--
-- Name: T_Niveau_5 Fk_TypeNiveau_5_Generique; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_TypeNiveau_5_Generique" FOREIGN KEY ("ID_TypeNiveau_5_Fk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_TypeNiveau_5_Generique" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_TypeNiveau_5_Generique" ON geolocalisation."T_Niveau_5" IS 'Référence physique du type de site vers T_Generique, contrôlée sans réaffectation des sites existants.';


--
-- Name: tr_coordonnees_territoire_integrite(); Type: FUNCTION; Schema: geolocalisation; Owner: -
--

CREATE FUNCTION geolocalisation.tr_coordonnees_territoire_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE parent_data jsonb; level integer; parent_id integer;
BEGIN
 IF TG_OP='UPDATE' AND ROW(NEW."ID_CoordonneesTerritoire",NEW."ID_Niveau_1Fk",NEW."ID_Niveau_2Fk",
   NEW."ID_Niveau_3Fk",NEW."ID_Niveau_4Fk",NEW."ID_Niveau_5Fk") IS DISTINCT FROM
   ROW(OLD."ID_CoordonneesTerritoire",OLD."ID_Niveau_1Fk",OLD."ID_Niveau_2Fk",OLD."ID_Niveau_3Fk",
   OLD."ID_Niveau_4Fk",OLD."ID_Niveau_5Fk") THEN
  RAISE EXCEPTION 'Le territoire d’une fiche de coordonnées enregistrée est conservé.'
   USING ERRCODE='23514',CONSTRAINT='ck_coordonnees_territoire_parent_immuable';
 END IF;
 -- Même verrou commun que l’édition territoriale dédiée. Une écriture SQL
 -- directe ne peut se glisser entre sa vérification de révision et l’upsert.
 -- Un ordre inverse externe peut produire un deadlock : PostgreSQL annule alors
 -- une transaction, sans écrasement silencieux de la dernière modification.
 parent_data:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
 FOR level IN 1..5 LOOP
  parent_id:=(parent_data->>('ID_Niveau_'||level||'Fk'))::integer;
  IF parent_id IS NOT NULL THEN
   EXECUTE format('SELECT 1 FROM geolocalisation.%I WHERE %I=$1 FOR UPDATE',
    'T_Niveau_'||level,'ID_Niveau_'||level) USING parent_id;
  END IF;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 NEW."ModifieLe":=clock_timestamp();
 NEW."ModifieParUserFk":=systeme.fn_admin_actor_user_id();
 RETURN NEW;
END $_$;

--
-- Name: FUNCTION tr_coordonnees_territoire_integrite(); Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON FUNCTION geolocalisation.tr_coordonnees_territoire_integrite() IS 'Verrouille le territoire parent pour chaque insertion, modification ou suppression, comme le service versionné. Préserve l’identité et le rattachement de la fiche ; impose horodatage et acteur transactionnel actif. Un ordre externe inverse peut provoquer un deadlock annulé par PostgreSQL, jamais une perte silencieuse. Le contexte d’audit ne constitue pas une permission.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_CoordonneesTerritoire; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_CoordonneesTerritoire" (
    "ID_CoordonneesTerritoire" bigint CONSTRAINT "T_CoordonneesTerritoire_ID_CoordonneesTerritoire_not_null" NOT NULL,
    "ID_Niveau_1Fk" integer,
    "ID_Niveau_2Fk" integer,
    "ID_Niveau_3Fk" integer,
    "ID_Niveau_4Fk" integer,
    "ID_Niveau_5Fk" integer,
    "AdresseTerritoire" text,
    "TelephoneTerritoire" character varying(50),
    "TelephoneSecondaireTerritoire" character varying(50),
    "EmailTerritoire" character varying(255),
    "SiteWebTerritoire" character varying(255),
    "InformationsAccueilTerritoire" text,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_CoordonneesTerritoire_ModifieLe_not_null" NOT NULL,
    "ModifieParUserFk" integer,
    "PublierCoordonneesAnnuaire" boolean DEFAULT false CONSTRAINT "T_CoordonneesTerritoire_PublierCoordonneesAnnuaire_not_null" NOT NULL,
    "HorairesOuvertureTerritoire" text,
    CONSTRAINT ck_coordonnees_territoire_accueil CHECK ((("InformationsAccueilTerritoire" IS NULL) OR ((char_length("InformationsAccueilTerritoire") >= 1) AND (char_length("InformationsAccueilTerritoire") <= 3000) AND ("InformationsAccueilTerritoire" = btrim("InformationsAccueilTerritoire")) AND (replace(replace("InformationsAccueilTerritoire", ''::text, ''::text), '
'::text, ''::text) !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_coordonnees_territoire_adresse CHECK ((("AdresseTerritoire" IS NULL) OR ((char_length("AdresseTerritoire") >= 1) AND (char_length("AdresseTerritoire") <= 2000) AND ("AdresseTerritoire" = btrim("AdresseTerritoire")) AND (replace(replace("AdresseTerritoire", ''::text, ''::text), '
'::text, ''::text) !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_coordonnees_territoire_email CHECK ((("EmailTerritoire" IS NULL) OR ((char_length(("EmailTerritoire")::text) >= 1) AND (char_length(("EmailTerritoire")::text) <= 255) AND (("EmailTerritoire")::text = btrim(("EmailTerritoire")::text)) AND (("EmailTerritoire")::text !~ '[[:space:][:cntrl:]]'::text)))),
    CONSTRAINT ck_coordonnees_territoire_horaires CHECK ((("HorairesOuvertureTerritoire" IS NULL) OR (((char_length("HorairesOuvertureTerritoire") >= 1) AND (char_length("HorairesOuvertureTerritoire") <= 1000)) AND ("HorairesOuvertureTerritoire" = btrim("HorairesOuvertureTerritoire")) AND (replace(replace("HorairesOuvertureTerritoire", ''::text, ''::text), '
'::text, ''::text) !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_coordonnees_territoire_parent_unique CHECK ((num_nonnulls("ID_Niveau_1Fk", "ID_Niveau_2Fk", "ID_Niveau_3Fk", "ID_Niveau_4Fk", "ID_Niveau_5Fk") = 1)),
    CONSTRAINT ck_coordonnees_territoire_site_web CHECK ((("SiteWebTerritoire" IS NULL) OR ((char_length(("SiteWebTerritoire")::text) >= 1) AND (char_length(("SiteWebTerritoire")::text) <= 255) AND (("SiteWebTerritoire")::text = btrim(("SiteWebTerritoire")::text)) AND (("SiteWebTerritoire")::text !~ '[[:space:][:cntrl:]]'::text)))),
    CONSTRAINT ck_coordonnees_territoire_telephone CHECK ((("TelephoneTerritoire" IS NULL) OR ((char_length(("TelephoneTerritoire")::text) >= 1) AND (char_length(("TelephoneTerritoire")::text) <= 50) AND (("TelephoneTerritoire")::text = btrim(("TelephoneTerritoire")::text)) AND (("TelephoneTerritoire")::text !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_coordonnees_territoire_telephone_secondaire CHECK ((("TelephoneSecondaireTerritoire" IS NULL) OR ((char_length(("TelephoneSecondaireTerritoire")::text) >= 1) AND (char_length(("TelephoneSecondaireTerritoire")::text) <= 50) AND (("TelephoneSecondaireTerritoire")::text = btrim(("TelephoneSecondaireTerritoire")::text)) AND (("TelephoneSecondaireTerritoire")::text !~ '[[:cntrl:]]'::text))))
);

--
-- Name: TABLE "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_CoordonneesTerritoire" IS 'Fiche institutionnelle partagée facultative d’un territoire N1 à N5, une seule FK explicite et immuable par fiche, sans entreprise propriétaire. Adresse, contacts, accueil et horaires déclarés sont conservés dans l’administration territoriale. Le consentement explicite PublierCoordonneesAnnuaire contrôle leur divulgation dans la projection sanitaire N3/N4/N5 ; aucune coordonnée de parent ou de personne n’est déduite. Auteur et date techniques ne constituent pas une vérification métier.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."ID_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ID_CoordonneesTerritoire" IS 'Identifiant technique unique de la fiche de coordonnées territoriales, généré en base.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."ID_Niveau_1Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ID_Niveau_1Fk" IS 'Rattachement explicite au territoire existant de niveau 1. Une seule des cinq FK est renseignée ; ce rattachement est immuable.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."ID_Niveau_2Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ID_Niveau_2Fk" IS 'Rattachement explicite au territoire existant de niveau 2. Une seule des cinq FK est renseignée ; ce rattachement est immuable.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."ID_Niveau_3Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ID_Niveau_3Fk" IS 'Rattachement explicite au territoire existant de niveau 3. Une seule des cinq FK est renseignée ; ce rattachement est immuable.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."ID_Niveau_4Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ID_Niveau_4Fk" IS 'Rattachement explicite au territoire existant de niveau 4. Une seule des cinq FK est renseignée ; ce rattachement est immuable.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."ID_Niveau_5Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ID_Niveau_5Fk" IS 'Rattachement explicite au territoire existant de niveau 5. Une seule des cinq FK est renseignée ; ce rattachement est immuable.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."AdresseTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."AdresseTerritoire" IS 'Adresse professionnelle déclarée, facultative, 2 000 caractères au maximum ; les retours à la ligne sont admis. Aucune localisation n’est calculée.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."TelephoneTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."TelephoneTerritoire" IS 'Téléphone professionnel principal déclaré pour ce territoire, facultatif, 50 caractères au maximum ; aucune qualification automatique.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."TelephoneSecondaireTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."TelephoneSecondaireTerritoire" IS 'Téléphone professionnel secondaire facultatif déclaré, 50 caractères au maximum, distinct des comptes utilisateurs.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."EmailTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."EmailTerritoire" IS 'Adresse e-mail professionnelle déclarée, facultative, 255 caractères au maximum sans espaces ni contrôles. Le format est validé par le service avant enregistrement.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."SiteWebTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."SiteWebTerritoire" IS 'URL professionnelle déclarée, facultative, 255 caractères au maximum sans espaces ni contrôles. Le service limite les liens aux schémas web autorisés.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."InformationsAccueilTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."InformationsAccueilTerritoire" IS 'Informations d’accueil déclarées en texte simple, facultatives, 3 000 caractères au maximum. Ne constitue pas une vérification d’horaires, d’agrément ou de permanence.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."ModifieLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ModifieLe" IS 'Instant technique réel de la dernière écriture, imposé par le trigger ; ne prouve pas une vérification métier des coordonnées.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."ModifieParUserFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ModifieParUserFk" IS 'Acteur actif du contexte systeme.actor_user_id, imposé par le trigger ; NULL lorsqu’aucun acteur valide n’est disponible. Ne constitue pas une autorisation.';

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_ID_CoordonneesTerritoire_not_null" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_ID_CoordonneesTerritoire_not_null" ON geolocalisation."T_CoordonneesTerritoire" IS 'Valeur technique obligatoire, produite et contrôlée en PostgreSQL.';

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_ModifieLe_not_null" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_ModifieLe_not_null" ON geolocalisation."T_CoordonneesTerritoire" IS 'Valeur technique obligatoire, produite et contrôlée en PostgreSQL.';

--
-- Name: CONSTRAINT ck_coordonnees_territoire_accueil ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_coordonnees_territoire_accueil ON geolocalisation."T_CoordonneesTerritoire" IS 'Contrôle du rattachement exclusif ou de la longueur et du contenu déclaré ; absence représentée par NULL. Définition : CHECK ((("InformationsAccueilTerritoire" IS NULL) OR (((char_length("InformationsAccueilTerritoire") >= 1) AND (char_length("InformationsAccueilTerritoire") <= 3000)) AND ("InformationsAccueilTerritoire" = btrim("InformationsAccueilTerritoire")) AND (replace(replace("InformationsAccueilTerritoire", ''''::text, ''''::text), ''
''::text, ''''::text) !~ ''[[:cntrl:]]''::text))))';

--
-- Name: CONSTRAINT ck_coordonnees_territoire_adresse ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_coordonnees_territoire_adresse ON geolocalisation."T_CoordonneesTerritoire" IS 'Contrôle du rattachement exclusif ou de la longueur et du contenu déclaré ; absence représentée par NULL. Définition : CHECK ((("AdresseTerritoire" IS NULL) OR (((char_length("AdresseTerritoire") >= 1) AND (char_length("AdresseTerritoire") <= 2000)) AND ("AdresseTerritoire" = btrim("AdresseTerritoire")) AND (replace(replace("AdresseTerritoire", ''''::text, ''''::text), ''
''::text, ''''::text) !~ ''[[:cntrl:]]''::text))))';

--
-- Name: CONSTRAINT ck_coordonnees_territoire_email ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_coordonnees_territoire_email ON geolocalisation."T_CoordonneesTerritoire" IS 'Contrôle du rattachement exclusif ou de la longueur et du contenu déclaré ; absence représentée par NULL. Définition : CHECK ((("EmailTerritoire" IS NULL) OR (((char_length(("EmailTerritoire")::text) >= 1) AND (char_length(("EmailTerritoire")::text) <= 255)) AND (("EmailTerritoire")::text = btrim(("EmailTerritoire")::text)) AND (("EmailTerritoire")::text !~ ''[[:space:][:cntrl:]]''::text))))';

--
-- Name: CONSTRAINT ck_coordonnees_territoire_parent_unique ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_coordonnees_territoire_parent_unique ON geolocalisation."T_CoordonneesTerritoire" IS 'Contrôle du rattachement exclusif ou de la longueur et du contenu déclaré ; absence représentée par NULL. Définition : CHECK ((num_nonnulls("ID_Niveau_1Fk", "ID_Niveau_2Fk", "ID_Niveau_3Fk", "ID_Niveau_4Fk", "ID_Niveau_5Fk") = 1))';

--
-- Name: CONSTRAINT ck_coordonnees_territoire_site_web ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_coordonnees_territoire_site_web ON geolocalisation."T_CoordonneesTerritoire" IS 'Contrôle du rattachement exclusif ou de la longueur et du contenu déclaré ; absence représentée par NULL. Définition : CHECK ((("SiteWebTerritoire" IS NULL) OR (((char_length(("SiteWebTerritoire")::text) >= 1) AND (char_length(("SiteWebTerritoire")::text) <= 255)) AND (("SiteWebTerritoire")::text = btrim(("SiteWebTerritoire")::text)) AND (("SiteWebTerritoire")::text !~ ''[[:space:][:cntrl:]]''::text))))';

--
-- Name: CONSTRAINT ck_coordonnees_territoire_telephone ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_coordonnees_territoire_telephone ON geolocalisation."T_CoordonneesTerritoire" IS 'Contrôle du rattachement exclusif ou de la longueur et du contenu déclaré ; absence représentée par NULL. Définition : CHECK ((("TelephoneTerritoire" IS NULL) OR (((char_length(("TelephoneTerritoire")::text) >= 1) AND (char_length(("TelephoneTerritoire")::text) <= 50)) AND (("TelephoneTerritoire")::text = btrim(("TelephoneTerritoire")::text)) AND (("TelephoneTerritoire")::text !~ ''[[:cntrl:]]''::text))))';

--
-- Name: CONSTRAINT ck_coordonnees_territoire_telephone_secondaire ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_coordonnees_territoire_telephone_secondaire ON geolocalisation."T_CoordonneesTerritoire" IS 'Contrôle du rattachement exclusif ou de la longueur et du contenu déclaré ; absence représentée par NULL. Définition : CHECK ((("TelephoneSecondaireTerritoire" IS NULL) OR (((char_length(("TelephoneSecondaireTerritoire")::text) >= 1) AND (char_length(("TelephoneSecondaireTerritoire")::text) <= 50)) AND (("TelephoneSecondaireTerritoire")::text = btrim(("TelephoneSecondaireTerritoire")::text)) AND (("TelephoneSecondaireTerritoire")::text !~ ''[[:cntrl:]]''::text))))';

--
-- Name: T_CoordonneesTerritoire_ID_CoordonneesTerritoire_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_CoordonneesTerritoire" ALTER COLUMN "ID_CoordonneesTerritoire" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_CoordonneesTerritoire_ID_CoordonneesTerritoire_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_CoordonneesTerritoire_ID_CoordonneesTerritoire_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_CoordonneesTerritoire_ID_CoordonneesTerritoire_seq" IS 'Génération de l’identifiant des coordonnées territoriales ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_CoordonneesTerritoire T_CoordonneesTerritoire_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CoordonneesTerritoire"
    ADD CONSTRAINT "T_CoordonneesTerritoire_pkey" PRIMARY KEY ("ID_CoordonneesTerritoire");

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_pkey" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_pkey" ON geolocalisation."T_CoordonneesTerritoire" IS 'Identifiant unique de la fiche de coordonnées territoriales.';

--
-- Name: uq_coordonnees_territoire_niveau_1; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_coordonnees_territoire_niveau_1 ON geolocalisation."T_CoordonneesTerritoire" USING btree ("ID_Niveau_1Fk") WHERE ("ID_Niveau_1Fk" IS NOT NULL);

--
-- Name: INDEX uq_coordonnees_territoire_niveau_1; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_coordonnees_territoire_niveau_1 IS 'Une seule fiche de coordonnées par territoire de niveau 1 ; aucune multiplication de lignes dans sa vue.';

--
-- Name: uq_coordonnees_territoire_niveau_2; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_coordonnees_territoire_niveau_2 ON geolocalisation."T_CoordonneesTerritoire" USING btree ("ID_Niveau_2Fk") WHERE ("ID_Niveau_2Fk" IS NOT NULL);

--
-- Name: INDEX uq_coordonnees_territoire_niveau_2; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_coordonnees_territoire_niveau_2 IS 'Une seule fiche de coordonnées par territoire de niveau 2 ; aucune multiplication de lignes dans sa vue.';

--
-- Name: uq_coordonnees_territoire_niveau_3; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_coordonnees_territoire_niveau_3 ON geolocalisation."T_CoordonneesTerritoire" USING btree ("ID_Niveau_3Fk") WHERE ("ID_Niveau_3Fk" IS NOT NULL);

--
-- Name: INDEX uq_coordonnees_territoire_niveau_3; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_coordonnees_territoire_niveau_3 IS 'Une seule fiche de coordonnées par territoire de niveau 3 ; aucune multiplication de lignes dans sa vue.';

--
-- Name: uq_coordonnees_territoire_niveau_4; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_coordonnees_territoire_niveau_4 ON geolocalisation."T_CoordonneesTerritoire" USING btree ("ID_Niveau_4Fk") WHERE ("ID_Niveau_4Fk" IS NOT NULL);

--
-- Name: INDEX uq_coordonnees_territoire_niveau_4; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_coordonnees_territoire_niveau_4 IS 'Une seule fiche de coordonnées par territoire de niveau 4 ; aucune multiplication de lignes dans sa vue.';

--
-- Name: uq_coordonnees_territoire_niveau_5; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_coordonnees_territoire_niveau_5 ON geolocalisation."T_CoordonneesTerritoire" USING btree ("ID_Niveau_5Fk") WHERE ("ID_Niveau_5Fk" IS NOT NULL);

--
-- Name: INDEX uq_coordonnees_territoire_niveau_5; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_coordonnees_territoire_niveau_5 IS 'Une seule fiche de coordonnées par territoire de niveau 5 ; aucune multiplication de lignes dans sa vue.';

--
-- Name: T_CoordonneesTerritoire coordonnees_territoire_integrite; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER coordonnees_territoire_integrite BEFORE INSERT OR DELETE OR UPDATE ON geolocalisation."T_CoordonneesTerritoire" FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_coordonnees_territoire_integrite();

--
-- Name: TRIGGER coordonnees_territoire_integrite ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER coordonnees_territoire_integrite ON geolocalisation."T_CoordonneesTerritoire" IS 'Verrouille le territoire parent pour toutes les écritures, contrôle les métadonnées et interdit de réaffecter une fiche existante à un autre territoire.';

--
-- Name: T_CoordonneesTerritoire T_CoordonneesTerritoire_ID_Niveau_1Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CoordonneesTerritoire"
    ADD CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_1Fk_fkey" FOREIGN KEY ("ID_Niveau_1Fk") REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1");

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_1Fk_fkey" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_1Fk_fkey" ON geolocalisation."T_CoordonneesTerritoire" IS 'Relation réelle imposée : aucun territoire ou acteur orphelin ; suppression du parent refusée tant que cette fiche le référence.';

--
-- Name: T_CoordonneesTerritoire T_CoordonneesTerritoire_ID_Niveau_2Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CoordonneesTerritoire"
    ADD CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_2Fk_fkey" FOREIGN KEY ("ID_Niveau_2Fk") REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2");

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_2Fk_fkey" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_2Fk_fkey" ON geolocalisation."T_CoordonneesTerritoire" IS 'Relation réelle imposée : aucun territoire ou acteur orphelin ; suppression du parent refusée tant que cette fiche le référence.';

--
-- Name: T_CoordonneesTerritoire T_CoordonneesTerritoire_ID_Niveau_3Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CoordonneesTerritoire"
    ADD CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_3Fk_fkey" FOREIGN KEY ("ID_Niveau_3Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3");

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_3Fk_fkey" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_3Fk_fkey" ON geolocalisation."T_CoordonneesTerritoire" IS 'Relation réelle imposée : aucun territoire ou acteur orphelin ; suppression du parent refusée tant que cette fiche le référence.';

--
-- Name: T_CoordonneesTerritoire T_CoordonneesTerritoire_ID_Niveau_4Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CoordonneesTerritoire"
    ADD CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_4Fk_fkey" FOREIGN KEY ("ID_Niveau_4Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4");

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_4Fk_fkey" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_4Fk_fkey" ON geolocalisation."T_CoordonneesTerritoire" IS 'Relation réelle imposée : aucun territoire ou acteur orphelin ; suppression du parent refusée tant que cette fiche le référence.';

--
-- Name: T_CoordonneesTerritoire T_CoordonneesTerritoire_ID_Niveau_5Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CoordonneesTerritoire"
    ADD CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_5Fk_fkey" FOREIGN KEY ("ID_Niveau_5Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5");

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_5Fk_fkey" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_ID_Niveau_5Fk_fkey" ON geolocalisation."T_CoordonneesTerritoire" IS 'Relation réelle imposée : aucun territoire ou acteur orphelin ; suppression du parent refusée tant que cette fiche le référence.';

--
-- Name: T_CoordonneesTerritoire T_CoordonneesTerritoire_ModifieParUserFk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CoordonneesTerritoire"
    ADD CONSTRAINT "T_CoordonneesTerritoire_ModifieParUserFk_fkey" FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser");

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_ModifieParUserFk_fkey" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_ModifieParUserFk_fkey" ON geolocalisation."T_CoordonneesTerritoire" IS 'Relation réelle imposée : aucun territoire ou acteur orphelin ; suppression du parent refusée tant que cette fiche le référence.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."PublierCoordonneesAnnuaire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."PublierCoordonneesAnnuaire" IS 'Autorisation explicite de divulguer les coordonnées institutionnelles et horaires dans l’annuaire sanitaire authentifié. False par défaut, y compris pour les fiches antérieures ; le retrait masque immédiatement les contacts sans supprimer le territoire ou sa fiche privée. Ne publie aucune entreprise ERP.';

--
-- Name: COLUMN "T_CoordonneesTerritoire"."HorairesOuvertureTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."HorairesOuvertureTerritoire" IS 'Horaires d’ouverture déclarés en texte simple facultatif, de 1 à 1 000 caractères après retrait des espaces extérieurs ; retours à la ligne admis. NULL signifie inconnus. Ne constitue pas un calcul « ouvert maintenant », une garde ou une vérification de permanence.';

--
-- Name: CONSTRAINT "T_CoordonneesTerritoire_PublierCoordonneesAnnuaire_not_null" ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CoordonneesTerritoire_PublierCoordonneesAnnuaire_not_null" ON geolocalisation."T_CoordonneesTerritoire" IS 'Choix explicite obligatoire, false par défaut : NULL ne vaut jamais autorisation.';

--
-- Name: CONSTRAINT ck_coordonnees_territoire_horaires ON "T_CoordonneesTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_coordonnees_territoire_horaires ON geolocalisation."T_CoordonneesTerritoire" IS 'Horaires déclarés facultatifs bornés à 1 000 caractères, sans contrôles autres que les retours à la ligne et sans espaces extérieurs.';

--
-- Name: tr_rapprochement_territorial_integrite(); Type: FUNCTION; Schema: geolocalisation; Owner: -
--

CREATE FUNCTION geolocalisation.tr_rapprochement_territorial_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog', 'geolocalisation'
    AS $$
DECLARE current_uid text; province_uid text; zone_uid text; area_uid text;
 local_n3 integer; local_n4 integer; local_n1 integer;
 source_parent integer; target_parent integer; source_type integer; target_type integer;
 source_province integer; target_province integer; source_type_label text; target_type_label text; parent_type_label text;
 source_name text; target_name text; source_uid text; target_uid text; matching_areas integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une preuve de rapprochement ne se supprime pas ; conserver sa version et sa décision.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_SourceRapprochementTerritorial' THEN
  IF TG_OP='UPDATE' THEN RAISE EXCEPTION 'La provenance est immuable ; enregistrer une nouvelle version de source.' USING ERRCODE='23514';END IF;
  NEW."CreeLe":=clock_timestamp();RETURN NEW;
 END IF;
 IF TG_OP='UPDATE' THEN
  IF OLD."Decision"<>'proposee' THEN RAISE EXCEPTION 'La décision finale est immuable ; réexaminer dans une nouvelle version de source.' USING ERRCODE='23514';END IF;
  IF (to_jsonb(NEW)-ARRAY['Decision','MotifDecision','DecideParUserFk','DecideLe']) IS DISTINCT FROM
     (to_jsonb(OLD)-ARRAY['Decision','MotifDecision','DecideParUserFk','DecideLe']) THEN
   RAISE EXCEPTION 'La cible et les preuves importées sont immuables ; créer une nouvelle version.' USING ERRCODE='23514';
  END IF;
 ELSE NEW."CreeLe":=clock_timestamp();END IF;
 IF NEW."Decision"='proposee' THEN
  NEW."DecideLe":=NULL;NEW."DecideParUserFk":=NULL;
 ELSE NEW."DecideLe":=clock_timestamp();END IF;
 IF NEW."Decision"<>'confirmee' THEN RETURN NEW;END IF;
 IF NEW."ConflitSource" THEN RAISE EXCEPTION 'Une correspondance en conflit ne peut pas être confirmée.' USING ERRCODE='23514';END IF;

 IF TG_TABLE_NAME='T_CorrespondanceTerritoriale' THEN
  IF NEW."ID_Niveau_1Fk" IS NOT NULL THEN
   local_n1:=NEW."ID_Niveau_1Fk";
   SELECT "uidSNIS" INTO current_uid FROM geolocalisation."T_Niveau_1" WHERE "ID_Niveau_1"=local_n1 FOR SHARE;
  ELSIF NEW."ID_Niveau_3Fk" IS NOT NULL THEN
   local_n3:=NEW."ID_Niveau_3Fk";
   SELECT "uidSNIS" INTO current_uid FROM geolocalisation."T_Niveau_3" WHERE "ID_Niveau_3"=local_n3 FOR SHARE;
  ELSIF NEW."ID_Niveau_4Fk" IS NOT NULL THEN
   local_n4:=NEW."ID_Niveau_4Fk";
   SELECT "uidSNIS","ID_Niveau_3_Fk" INTO current_uid,local_n3 FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=local_n4 FOR SHARE;
  ELSE
   SELECT "uidSNIS","ID_Niveau_3_Fk","ID_Niveau_4_Fk" INTO current_uid,local_n3,local_n4 FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=NEW."ID_Niveau_5Fk" FOR SHARE;
   IF local_n4 IS NOT NULL THEN
    SELECT "ID_Niveau_3_Fk" INTO target_parent FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=local_n4 FOR SHARE;
    IF local_n3 IS NOT NULL AND target_parent IS NOT NULL AND local_n3<>target_parent THEN
     RAISE EXCEPTION 'Le site et son aire indiquent des zones contradictoires.' USING ERRCODE='23514';
    END IF;
    local_n3:=coalesce(local_n3,target_parent);
   END IF;
  END IF;
  IF local_n3 IS NOT NULL THEN
   SELECT n3."uidSNIS",n2."ID_Niveau_1_FK" INTO zone_uid,local_n1
    FROM geolocalisation."T_Niveau_3" n3 LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK" WHERE n3."ID_Niveau_3"=local_n3;
  END IF;
  IF local_n4 IS NOT NULL THEN SELECT "uidSNIS" INTO area_uid FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=local_n4;END IF;
  IF local_n1 IS NOT NULL THEN SELECT "uidSNIS" INTO province_uid FROM geolocalisation."T_Niveau_1" WHERE "ID_Niveau_1"=local_n1;END IF;
  IF (nullif(btrim(current_uid),'') IS NOT NULL AND nullif(btrim(NEW."UidSNISSource"),'') IS NOT NULL AND current_uid<>NEW."UidSNISSource")
   OR (nullif(btrim(province_uid),'') IS NOT NULL AND nullif(btrim(NEW."UidProvinceSource"),'') IS NOT NULL AND province_uid<>NEW."UidProvinceSource")
   OR (nullif(btrim(zone_uid),'') IS NOT NULL AND nullif(btrim(NEW."UidZoneSource"),'') IS NOT NULL AND zone_uid<>NEW."UidZoneSource")
   OR (nullif(btrim(area_uid),'') IS NOT NULL AND nullif(btrim(NEW."UidAireSource"),'') IS NOT NULL AND area_uid<>NEW."UidAireSource") THEN
   RAISE EXCEPTION 'Identifiant SNIS ou parent existant contradictoire ; conserver la proposition pour validation.' USING ERRCODE='23514';
  END IF;
  IF nullif(btrim(NEW."UidSNISSource"),'') IS NOT NULL THEN
   PERFORM pg_advisory_xact_lock(hashtextextended('geolocalisation:uid-snis:'||NEW."UidSNISSource",0));
   IF EXISTS(SELECT FROM geolocalisation."T_CorrespondanceTerritoriale" c WHERE c."Decision"='confirmee'
    AND c."ID_CorrespondanceTerritoriale"<>NEW."ID_CorrespondanceTerritoriale"
    AND c."UidSNISSource"=NEW."UidSNISSource"
    AND ROW(c."ID_Niveau_1Fk",c."ID_Niveau_3Fk",c."ID_Niveau_4Fk",c."ID_Niveau_5Fk") IS DISTINCT FROM ROW(NEW."ID_Niveau_1Fk",NEW."ID_Niveau_3Fk",NEW."ID_Niveau_4Fk",NEW."ID_Niveau_5Fk")) THEN
    RAISE EXCEPTION 'Le même UID SNIS confirmé désigne déjà une autre identité locale ; conserver le conflit proposé.' USING ERRCODE='23514';
   END IF;
  END IF;
 ELSE
  IF NEW."NatureLien"='copie_n5_n4' THEN
   SELECT "ID_Niveau_3_Fk","ID_TypeNiveau_5_Fk","NomNiveau_5","uidSNIS" INTO source_parent,source_type,source_name,source_uid FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=NEW."ID_OrigineNiveau_5Fk" FOR SHARE;
   SELECT "ID_Niveau_3_Fk","ID_TypeNiveau_4_Fk","NomNiveau_4","uidSNIS" INTO target_parent,target_type,target_name,target_uid FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=NEW."ID_CibleNiveau_4Fk" FOR SHARE;
   SELECT count(*) INTO matching_areas FROM geolocalisation."T_Niveau_4" n WHERE n."ID_Niveau_3_Fk"=source_parent AND n."ID_TypeNiveau_4_Fk"=source_type
    AND referentiel.fn_normaliser_libelle(n."NomNiveau_4")=referentiel.fn_normaliser_libelle(source_name);
   IF source_parent IS NULL OR target_parent IS NULL OR source_parent<>target_parent OR source_type IS NULL OR target_type IS NULL OR source_type<>target_type
    OR nullif(btrim(source_name),'') IS NULL OR referentiel.fn_normaliser_libelle(source_name) IS DISTINCT FROM referentiel.fn_normaliser_libelle(target_name)
    OR matching_areas<>1 OR (nullif(btrim(source_uid),'') IS NOT NULL AND nullif(btrim(target_uid),'') IS NOT NULL AND source_uid<>target_uid) THEN
    RAISE EXCEPTION 'Une copie N5/N4 confirmée exige un nom, un type et un parent concordants, une cible unique et aucun UID contradictoire ; aucune fusion par homonymie.' USING ERRCODE='23514';
   END IF;
  ELSIF NEW."NatureLien"='aire_de_zone' THEN
   SELECT n."ID_Niveau_3_Fk",g."AbrGenerique" INTO source_parent,source_type_label
    FROM geolocalisation."T_Niveau_4" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_4_Fk"
    WHERE n."ID_Niveau_4"=NEW."ID_OrigineNiveau_4Fk" FOR SHARE OF n;
   SELECT g."AbrGenerique",n2."ID_Niveau_1_FK" INTO target_type_label,target_province
    FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk"
    JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n."ID_Niveau_2_FK"
    WHERE n."ID_Niveau_3"=NEW."ID_CibleNiveau_3Fk";
   SELECT n2."ID_Niveau_1_FK",g."AbrGenerique" INTO source_province,parent_type_label
    FROM geolocalisation."T_Niveau_3" n JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n."ID_Niveau_2_FK"
    JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_3"=source_parent;
   IF NOT coalesce(source_type_label='AS' AND target_type_label='ZS' AND parent_type_label IN ('BCZS','ZS'),false)
    OR source_province IS NULL OR target_province IS NULL OR source_province<>target_province
    OR (parent_type_label='ZS' AND source_parent<>NEW."ID_CibleNiveau_3Fk")
    OR EXISTS(SELECT FROM geolocalisation."T_LienTerritorial" l WHERE l."NatureLien"='bureau_de_zone' AND l."Decision"='confirmee'
      AND l."ID_OrigineNiveau_3Fk"=source_parent AND l."ID_CibleNiveau_3Fk"<>NEW."ID_CibleNiveau_3Fk") THEN
    RAISE EXCEPTION 'Le lien aire-zone exige une AS, une ZS et une province concordantes, sans contredire le parent sanitaire prouvé.' USING ERRCODE='23514';
   END IF;
  ELSE
   SELECT n2."ID_Niveau_1_FK" INTO source_province FROM geolocalisation."T_Niveau_3" n3 JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK" WHERE n3."ID_Niveau_3"=NEW."ID_OrigineNiveau_3Fk";
   IF NEW."NatureLien"='bureau_de_zone' THEN
    SELECT n2."ID_Niveau_1_FK" INTO target_province FROM geolocalisation."T_Niveau_3" n3 JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK" WHERE n3."ID_Niveau_3"=NEW."ID_CibleNiveau_3Fk";
    SELECT g."AbrGenerique" INTO source_type_label FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_3"=NEW."ID_OrigineNiveau_3Fk";
    SELECT g."AbrGenerique" INTO target_type_label FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_3"=NEW."ID_CibleNiveau_3Fk";
    IF NOT coalesce(source_type_label='BCZS' AND target_type_label='ZS',false) THEN
     RAISE EXCEPTION 'Le bureau de zone exige un BCZS d’origine et une ZS cible distincte ; un bureau ne devient pas la zone desservie.' USING ERRCODE='23514';
    END IF;
   ELSE
    SELECT "ID_Niveau_1_FK" INTO target_province FROM geolocalisation."T_Niveau_2" WHERE "ID_Niveau_2"=NEW."ID_CibleNiveau_2Fk";
    SELECT g."AbrGenerique" INTO source_type_label FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_3"=NEW."ID_OrigineNiveau_3Fk";
    SELECT g."AbrGenerique" INTO target_type_label FROM geolocalisation."T_Niveau_2" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_2"=NEW."ID_CibleNiveau_2Fk";
    IF NOT coalesce(source_type_label='ZS' AND target_type_label='Ant PEV',false) THEN
     RAISE EXCEPTION 'Un rattachement sanitaire exige une ZS et une antenne PEV identifiées par le référentiel.' USING ERRCODE='23514';
    END IF;
   END IF;
   IF source_province IS NULL OR target_province IS NULL OR source_province<>target_province THEN
    RAISE EXCEPTION 'Un lien bureau-zone ou un rattachement sanitaire confirmé exige une province commune prouvée.' USING ERRCODE='23514';
   END IF;
  END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_rapprochement_territorial_integrite(); Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON FUNCTION geolocalisation.tr_rapprochement_territorial_integrite() IS 'Garde transactionnelle additive du rapprochement : sources, preuves, cibles et décisions finales immuables, acteur/motif pour les décisions, refus des UID ou parents contradictoires. Ne peuple aucun UID, parent ou GPS ; n’accorde aucun droit applicatif.';

--
-- Name: tr_uid_snis_integrite(); Type: FUNCTION; Schema: geolocalisation; Owner: -
--

CREATE FUNCTION geolocalisation.tr_uid_snis_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
BEGIN
 -- Une modification descriptive n'oblige pas à réécrire une identité historique.
 IF TG_OP='UPDATE' AND NEW."uidSNIS" IS NOT DISTINCT FROM OLD."uidSNIS" THEN RETURN NEW;END IF;
 IF NEW."uidSNIS" IS NULL THEN RETURN NEW;END IF;
 IF NEW."uidSNIS" !~ '^[A-Za-z][A-Za-z0-9]{10}$' THEN
  RAISE EXCEPTION 'Identifiant SNIS invalide : saisir les 11 caractères DHIS2 (une lettre puis lettres ou chiffres), ou laisser vide.' USING ERRCODE='23514', CONSTRAINT='ck_uid_snis_format';
 END IF;
 RETURN NEW;
END $_$;

--
-- Name: FUNCTION tr_uid_snis_integrite(); Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON FUNCTION geolocalisation.tr_uid_snis_integrite() IS 'Contrôle des nouveaux UID SNIS/DHIS2 N1/N3/N4 : NULL ou 11 caractères, première lettre, sans espaces et avec casse conservée. Les valeurs inchangées sont conservées ; une correction d’UID valide reste possible sous les droits et audits métier existants. Ne valide pas la correspondance scientifique d’un UID ni son unicité entre niveaux.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_CorrespondanceTerritoriale; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_CorrespondanceTerritoriale" (
    "ID_CorrespondanceTerritoriale" bigint CONSTRAINT "T_CorrespondanceTerritorial_ID_CorrespondanceTerritori_not_null" NOT NULL,
    "ID_SourceRapprochementFk" bigint CONSTRAINT "T_CorrespondanceTerritoriale_ID_SourceRapprochementFk_not_null" NOT NULL,
    "CleLigneSource" text CONSTRAINT "T_CorrespondanceTerritoriale_CleLigneSource_not_null" NOT NULL,
    "UidSource" text,
    "UidSNISSource" text,
    "UidProvinceSource" text,
    "UidZoneSource" text,
    "UidAireSource" text,
    "Grid3Id" text,
    "NomSource" text,
    "ID_Niveau_1Fk" integer,
    "ID_Niveau_3Fk" integer,
    "ID_Niveau_4Fk" integer,
    "ID_Niveau_5Fk" integer,
    "Decision" text DEFAULT 'proposee'::text CONSTRAINT "T_CorrespondanceTerritoriale_Decision_not_null" NOT NULL,
    "ConflitSource" boolean DEFAULT false CONSTRAINT "T_CorrespondanceTerritoriale_ConflitSource_not_null" NOT NULL,
    "Preuves" jsonb DEFAULT '{}'::jsonb CONSTRAINT "T_CorrespondanceTerritoriale_Preuves_not_null" NOT NULL,
    "MotifDecision" text,
    "DecideParUserFk" integer,
    "DecideLe" timestamp with time zone,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_CorrespondanceTerritoriale_CreeLe_not_null" NOT NULL,
    CONSTRAINT "T_CorrespondanceTerritoriale_CleLigneSource_check" CHECK (((length(btrim("CleLigneSource")) >= 1) AND (length(btrim("CleLigneSource")) <= 500))),
    CONSTRAINT "T_CorrespondanceTerritoriale_Decision_check" CHECK (("Decision" = ANY (ARRAY['proposee'::text, 'confirmee'::text, 'refusee'::text]))),
    CONSTRAINT "T_CorrespondanceTerritoriale_Preuves_check" CHECK ((jsonb_typeof("Preuves") = 'object'::text)),
    CONSTRAINT ck_correspondance_conflit_non_confirme CHECK ((("Decision" <> 'confirmee'::text) OR (NOT "ConflitSource"))),
    CONSTRAINT ck_correspondance_decision_tracee CHECK ((("Decision" = 'proposee'::text) OR ((length(btrim("MotifDecision")) > 0) AND ("MotifDecision" IS NOT NULL) AND ("DecideParUserFk" IS NOT NULL) AND ("DecideLe" IS NOT NULL) AND ("Preuves" <> '{}'::jsonb)))),
    CONSTRAINT ck_correspondance_une_cible CHECK ((num_nonnulls("ID_Niveau_1Fk", "ID_Niveau_3Fk", "ID_Niveau_4Fk", "ID_Niveau_5Fk") = 1))
);

--
-- Name: TABLE "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_CorrespondanceTerritoriale" IS 'Correspondance documentée d’une ligne source vers une seule vraie FK territoriale N1, N3, N4 ou N5. Un objet GRID3 est unique dans sa version de source, mais plusieurs objets GRID3 peuvent pointer vers une même aire ; aucune unicité artificielle par aire n’est déduite. Une confirmation ne modifie ni uidSNIS ni la hiérarchie : une migration de données contrôlée et validée est nécessaire.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."ID_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."ID_CorrespondanceTerritoriale" IS 'Clé primaire technique de la preuve de correspondance, distincte des identifiants externes et des clés territoriales.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."ID_SourceRapprochementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."ID_SourceRapprochementFk" IS 'Vraie FK vers la version immuable de provenance ; plusieurs lignes peuvent partager cette source.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."CleLigneSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."CleLigneSource" IS 'Clé textuelle stable de ligne dans cette version de source, éventuellement feuille et numéro de ligne ; unique avec la source.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."UidSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."UidSource" IS 'Identifiant externe tel que fourni, sans le confondre par égalité textuelle avec un UID SNIS.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."UidSNISSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."UidSNISSource" IS 'UID SNIS/DHIS2 explicitement proposé par la source, distinct du champ uidSNIS territorial ; un conflit existant interdit la confirmation.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."UidProvinceSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."UidProvinceSource" IS 'Identifiant externe de la province parente cité dans la preuve ; comparaison SNIS seulement si cette identité est prouvée.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."UidZoneSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."UidZoneSource" IS 'Identifiant externe de zone de santé cité dans la preuve, sans écrasement du rattachement existant.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."UidAireSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."UidAireSource" IS 'Identifiant externe de l’aire de santé ; plusieurs objets GRID3 peuvent partager cette valeur.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."Grid3Id"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."Grid3Id" IS 'Identifiant de l’objet GRID3 source, conservé textuellement sans supposer une relation un-à-un avec l’aire métier.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."NomSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."NomSource" IS 'Libellé original de la ligne externe, conservé pour vérifier et expliquer la correspondance.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."ID_Niveau_1Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."ID_Niveau_1Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."ID_Niveau_3Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."ID_Niveau_3Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."ID_Niveau_4Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."ID_Niveau_4Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."ID_Niveau_5Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."ID_Niveau_5Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."Decision"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."Decision" IS 'État technique de revue : proposee, confirmee ou refusee. La proposition ne vaut pas modification métier ; la décision finale est immuable.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."ConflitSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."ConflitSource" IS 'Conflit détecté entre identifiants, parents ou sources ; une ligne en conflit ne peut pas être confirmée.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."Preuves"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."Preuves" IS 'Éléments immuables justifiant la proposition : méthode, noms, parents et références de ligne ; objet non vide requis pour conclure.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."MotifDecision"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."MotifDecision" IS 'Justification obligatoire d’une confirmation ou d’un refus, sans effacer les données source.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."DecideParUserFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."DecideParUserFk" IS 'Compte métier existant ayant pris la décision ; une GUC de session ne vaut pas autorisation.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."DecideLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."DecideLe" IS 'Instant technique de décision renseigné par le trigger ; NULL pour une proposition non décidée.';

--
-- Name: COLUMN "T_CorrespondanceTerritoriale"."CreeLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_CorrespondanceTerritoriale"."CreeLe" IS 'Instant technique de conservation de la preuve, indépendant de la date des données source.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritorial_ID_CorrespondanceTerritori_not_null" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritorial_ID_CorrespondanceTerritori_not_null" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_ID_SourceRapprochementFk_not_null" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_ID_SourceRapprochementFk_not_null" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_CleLigneSource_not_null" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_CleLigneSource_not_null" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_Decision_not_null" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_Decision_not_null" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_ConflitSource_not_null" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_ConflitSource_not_null" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_Preuves_not_null" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_Preuves_not_null" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_CreeLe_not_null" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_CreeLe_not_null" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_CleLigneSource_check" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_CleLigneSource_check" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_Decision_check" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_Decision_check" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_Preuves_check" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_Preuves_check" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT ck_correspondance_conflit_non_confirme ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_correspondance_conflit_non_confirme ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT ck_correspondance_decision_tracee ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_correspondance_decision_tracee ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT ck_correspondance_une_cible ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_correspondance_une_cible ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_CorrespondanceTerritoriale_ID_CorrespondanceTerritoriale_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_CorrespondanceTerritoriale" ALTER COLUMN "ID_CorrespondanceTerritoriale" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_CorrespondanceTerritoriale_ID_CorrespondanceTerritoriale_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_CorrespondanceTerritoriale_ID_CorrespondanceTerritoriale_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_CorrespondanceTerritoriale_ID_CorrespondanceTerritoriale_seq" IS 'Séquence technique d’identité du rapprochement ; aucun UID externe ou code métier n’est généré par cette séquence.';

--
-- Name: T_LienTerritorial; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_LienTerritorial" (
    "ID_LienTerritorial" bigint CONSTRAINT "T_LienTerritorial_ID_LienTerritorial_not_null" NOT NULL,
    "ID_SourceRapprochementFk" bigint CONSTRAINT "T_LienTerritorial_ID_SourceRapprochementFk_not_null" NOT NULL,
    "CleLienSource" text CONSTRAINT "T_LienTerritorial_CleLienSource_not_null" NOT NULL,
    "NatureLien" text CONSTRAINT "T_LienTerritorial_NatureLien_not_null" NOT NULL,
    "DomaineLien" text CONSTRAINT "T_LienTerritorial_DomaineLien_not_null" NOT NULL,
    "ID_OrigineNiveau_3Fk" integer,
    "ID_OrigineNiveau_4Fk" integer,
    "ID_OrigineNiveau_5Fk" integer,
    "ID_CibleNiveau_2Fk" integer,
    "ID_CibleNiveau_3Fk" integer,
    "ID_CibleNiveau_4Fk" integer,
    "Decision" text DEFAULT 'proposee'::text CONSTRAINT "T_LienTerritorial_Decision_not_null" NOT NULL,
    "ConflitSource" boolean DEFAULT false CONSTRAINT "T_LienTerritorial_ConflitSource_not_null" NOT NULL,
    "Preuves" jsonb DEFAULT '{}'::jsonb CONSTRAINT "T_LienTerritorial_Preuves_not_null" NOT NULL,
    "MotifDecision" text,
    "DecideParUserFk" integer,
    "DecideLe" timestamp with time zone,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_LienTerritorial_CreeLe_not_null" NOT NULL,
    CONSTRAINT "T_LienTerritorial_CleLienSource_check" CHECK (((length(btrim("CleLienSource")) >= 1) AND (length(btrim("CleLienSource")) <= 500))),
    CONSTRAINT "T_LienTerritorial_Decision_check" CHECK (("Decision" = ANY (ARRAY['proposee'::text, 'confirmee'::text, 'refusee'::text]))),
    CONSTRAINT "T_LienTerritorial_DomaineLien_check" CHECK (("DomaineLien" = ANY (ARRAY['sanitaire'::text, 'administratif'::text, 'compatibilite'::text]))),
    CONSTRAINT "T_LienTerritorial_NatureLien_check" CHECK (("NatureLien" = ANY (ARRAY['copie_n5_n4'::text, 'bureau_de_zone'::text, 'rattachement_sanitaire'::text, 'aire_de_zone'::text]))),
    CONSTRAINT "T_LienTerritorial_Preuves_check" CHECK ((jsonb_typeof("Preuves") = 'object'::text)),
    CONSTRAINT ck_lien_territorial_conflit_non_confirme CHECK ((("Decision" <> 'confirmee'::text) OR (NOT "ConflitSource"))),
    CONSTRAINT ck_lien_territorial_decision_tracee CHECK ((("Decision" = 'proposee'::text) OR ((length(btrim("MotifDecision")) > 0) AND ("MotifDecision" IS NOT NULL) AND ("DecideParUserFk" IS NOT NULL) AND ("DecideLe" IS NOT NULL) AND ("Preuves" <> '{}'::jsonb)))),
    CONSTRAINT ck_lien_territorial_forme CHECK (((num_nonnulls("ID_OrigineNiveau_3Fk", "ID_OrigineNiveau_4Fk", "ID_OrigineNiveau_5Fk") = 1) AND (num_nonnulls("ID_CibleNiveau_2Fk", "ID_CibleNiveau_3Fk", "ID_CibleNiveau_4Fk") = 1) AND ((("NatureLien" = 'copie_n5_n4'::text) AND ("ID_OrigineNiveau_5Fk" IS NOT NULL) AND ("ID_CibleNiveau_4Fk" IS NOT NULL)) OR (("NatureLien" = 'bureau_de_zone'::text) AND ("DomaineLien" = 'sanitaire'::text) AND ("ID_OrigineNiveau_3Fk" IS NOT NULL) AND ("ID_CibleNiveau_3Fk" IS NOT NULL) AND ("ID_OrigineNiveau_3Fk" <> "ID_CibleNiveau_3Fk")) OR (("NatureLien" = 'rattachement_sanitaire'::text) AND ("DomaineLien" = 'sanitaire'::text) AND ("ID_OrigineNiveau_3Fk" IS NOT NULL) AND ("ID_CibleNiveau_2Fk" IS NOT NULL)) OR (("NatureLien" = 'aire_de_zone'::text) AND ("DomaineLien" = 'sanitaire'::text) AND ("ID_OrigineNiveau_4Fk" IS NOT NULL) AND ("ID_CibleNiveau_3Fk" IS NOT NULL)))))
);

--
-- Name: TABLE "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_LienTerritorial" IS 'Liens explicites versionnés entre identités locales conservées : copie N5/N4, bureau BCZS vers zone ZS distincte, rattachement sanitaire ZS vers antenne PEV ou aire AS vers zone ZS canonique. Un bureau et sa zone ne sont pas une même identité et ne partagent pas leur UID par déduction. Ne fusionne pas les organisations administrative et sanitaire, ne déplace pas les parents physiques historiques et ne supprime aucune copie utilisée comme destination.';

--
-- Name: COLUMN "T_LienTerritorial"."ID_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ID_LienTerritorial" IS 'Clé primaire technique du lien local versionné ; ne remplace aucune identité N2, N3, N4 ou N5.';

--
-- Name: COLUMN "T_LienTerritorial"."ID_SourceRapprochementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ID_SourceRapprochementFk" IS 'Vraie FK vers la version immuable de provenance ; plusieurs lignes peuvent partager cette source.';

--
-- Name: COLUMN "T_LienTerritorial"."CleLienSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."CleLienSource" IS 'Clé stable de la proposition de lien dans sa version de source ; unique avec cette version.';

--
-- Name: COLUMN "T_LienTerritorial"."NatureLien"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."NatureLien" IS 'Forme technique fermée : copie_n5_n4, bureau_de_zone (BCZS vers ZS distincte), rattachement_sanitaire (ZS vers antenne PEV) ou aire_de_zone (AS vers ZS canonique). Ne remplace pas le type catégoriel et ne fusionne pas le bureau et sa zone.';

--
-- Name: COLUMN "T_LienTerritorial"."DomaineLien"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."DomaineLien" IS 'Organisation concernée par la proposition : sanitaire, administratif ou compatibilite ; ne déduit aucune équivalence de périmètre.';

--
-- Name: COLUMN "T_LienTerritorial"."ID_OrigineNiveau_3Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ID_OrigineNiveau_3Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_LienTerritorial"."ID_OrigineNiveau_4Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ID_OrigineNiveau_4Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_LienTerritorial"."ID_OrigineNiveau_5Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ID_OrigineNiveau_5Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_LienTerritorial"."ID_CibleNiveau_2Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ID_CibleNiveau_2Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_LienTerritorial"."ID_CibleNiveau_3Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ID_CibleNiveau_3Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_LienTerritorial"."ID_CibleNiveau_4Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ID_CibleNiveau_4Fk" IS 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.';

--
-- Name: COLUMN "T_LienTerritorial"."Decision"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."Decision" IS 'État technique de revue : proposee, confirmee ou refusee. La proposition ne vaut pas modification métier ; la décision finale est immuable.';

--
-- Name: COLUMN "T_LienTerritorial"."ConflitSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."ConflitSource" IS 'Conflit détecté entre identifiants, parents ou sources ; une ligne en conflit ne peut pas être confirmée.';

--
-- Name: COLUMN "T_LienTerritorial"."Preuves"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."Preuves" IS 'Éléments immuables justifiant la proposition : méthode, noms, parents et références de ligne ; objet non vide requis pour conclure.';

--
-- Name: COLUMN "T_LienTerritorial"."MotifDecision"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."MotifDecision" IS 'Justification obligatoire d’une confirmation ou d’un refus, sans effacer les données source.';

--
-- Name: COLUMN "T_LienTerritorial"."DecideParUserFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."DecideParUserFk" IS 'Compte métier existant ayant pris la décision ; une GUC de session ne vaut pas autorisation.';

--
-- Name: COLUMN "T_LienTerritorial"."DecideLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."DecideLe" IS 'Instant technique de décision renseigné par le trigger ; NULL pour une proposition non décidée.';

--
-- Name: COLUMN "T_LienTerritorial"."CreeLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_LienTerritorial"."CreeLe" IS 'Instant technique de conservation de la preuve, indépendant de la date des données source.';

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_LienTerritorial_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_LienTerritorial_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_SourceRapprochementFk_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_SourceRapprochementFk_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_CleLienSource_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_CleLienSource_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_NatureLien_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_NatureLien_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_DomaineLien_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_DomaineLien_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_Decision_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_Decision_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_ConflitSource_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ConflitSource_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_Preuves_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_Preuves_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_CreeLe_not_null" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_CreeLe_not_null" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_CleLienSource_check" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_CleLienSource_check" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_Decision_check" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_Decision_check" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_DomaineLien_check" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_DomaineLien_check" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_NatureLien_check" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_NatureLien_check" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_LienTerritorial_Preuves_check" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_Preuves_check" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT ck_lien_territorial_conflit_non_confirme ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_lien_territorial_conflit_non_confirme ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT ck_lien_territorial_decision_tracee ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_lien_territorial_decision_tracee ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT ck_lien_territorial_forme ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT ck_lien_territorial_forme ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial_ID_LienTerritorial_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_LienTerritorial" ALTER COLUMN "ID_LienTerritorial" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_LienTerritorial_ID_LienTerritorial_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_LienTerritorial_ID_LienTerritorial_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_LienTerritorial_ID_LienTerritorial_seq" IS 'Séquence technique d’identité du rapprochement ; aucun UID externe ou code métier n’est généré par cette séquence.';

--
-- Name: COLUMN "T_Niveau_1"."uidSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."uidSNIS" IS 'Identifiant SNIS/DHIS2 propre à cette identité territoriale, NULL si non rapprochée avec preuve. Les nouvelles valeurs ont 11 caractères (lettre puis lettres ou chiffres), sans espaces ; leur casse est significative. Unique localement dans ce niveau, sans copie vers un bureau, une autre organisation ou un autre niveau. L’import vérifie aussi la cohérence inter-niveaux et la provenance.';

--
-- Name: COLUMN "T_Niveau_3"."uidSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."uidSNIS" IS 'Identifiant SNIS/DHIS2 propre à cette identité territoriale, NULL si non rapprochée avec preuve. Les nouvelles valeurs ont 11 caractères (lettre puis lettres ou chiffres), sans espaces ; leur casse est significative. Unique localement dans ce niveau, sans copie vers un bureau, une autre organisation ou un autre niveau. L’import vérifie aussi la cohérence inter-niveaux et la provenance.';

--
-- Name: COLUMN "T_Niveau_4"."uidSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."uidSNIS" IS 'Identifiant SNIS/DHIS2 propre à cette identité territoriale, NULL si non rapprochée avec preuve. Les nouvelles valeurs ont 11 caractères (lettre puis lettres ou chiffres), sans espaces ; leur casse est significative. Unique localement dans ce niveau, sans copie vers un bureau, une autre organisation ou un autre niveau. L’import vérifie aussi la cohérence inter-niveaux et la provenance.';

--
-- Name: T_SourceRapprochementTerritorial; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_SourceRapprochementTerritorial" (
    "ID_SourceRapprochementTerritorial" bigint CONSTRAINT "T_SourceRapprochementTerrit_ID_SourceRapprochementTerr_not_null" NOT NULL,
    "CodeSource" text CONSTRAINT "T_SourceRapprochementTerritorial_CodeSource_not_null" NOT NULL,
    "VersionSource" text CONSTRAINT "T_SourceRapprochementTerritorial_VersionSource_not_null" NOT NULL,
    "Sha256Source" text CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_not_null" NOT NULL,
    "NomFichierSource" text CONSTRAINT "T_SourceRapprochementTerritorial_NomFichierSource_not_null" NOT NULL,
    "DateSource" date,
    "MetadonneesSource" jsonb DEFAULT '{}'::jsonb CONSTRAINT "T_SourceRapprochementTerritorial_MetadonneesSource_not_null" NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_SourceRapprochementTerritorial_CreeLe_not_null" NOT NULL,
    CONSTRAINT "T_SourceRapprochementTerritorial_CodeSource_check" CHECK (((length(btrim("CodeSource")) >= 1) AND (length(btrim("CodeSource")) <= 80))),
    CONSTRAINT "T_SourceRapprochementTerritorial_MetadonneesSource_check" CHECK ((jsonb_typeof("MetadonneesSource") = 'object'::text)),
    CONSTRAINT "T_SourceRapprochementTerritorial_NomFichierSource_check" CHECK (((length(btrim("NomFichierSource")) >= 1) AND (length(btrim("NomFichierSource")) <= 255))),
    CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_check" CHECK (("Sha256Source" ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT "T_SourceRapprochementTerritorial_VersionSource_check" CHECK (((length(btrim("VersionSource")) >= 1) AND (length(btrim("VersionSource")) <= 160)))
);

--
-- Name: TABLE "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_SourceRapprochementTerritorial" IS 'Version immuable et empreinte vérifiable d’une source de rapprochement géographique. Socle installé sans import implicite ; toute application d’une décision utilise une migration de données contrôlée. Ne contient aucune géométrie fabriquée à partir de surfaces ou de longueurs.';

--
-- Name: COLUMN "T_SourceRapprochementTerritorial"."ID_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_SourceRapprochementTerritorial"."ID_SourceRapprochementTerritorial" IS 'Identifiant technique stable de cette version de source.';

--
-- Name: COLUMN "T_SourceRapprochementTerritorial"."CodeSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_SourceRapprochementTerritorial"."CodeSource" IS 'Nom technique de la source, par exemple SNIS/DHIS2, GRID3 ou un état local ; ne constitue pas une catégorie métier.';

--
-- Name: COLUMN "T_SourceRapprochementTerritorial"."VersionSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_SourceRapprochementTerritorial"."VersionSource" IS 'Version ou date déclarée de la source ; ne pas remplacer une version antérieure.';

--
-- Name: COLUMN "T_SourceRapprochementTerritorial"."Sha256Source"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_SourceRapprochementTerritorial"."Sha256Source" IS 'Empreinte SHA-256 des octets du fichier ou de l’état source, 64 caractères hexadécimaux minuscules uniques.';

--
-- Name: COLUMN "T_SourceRapprochementTerritorial"."NomFichierSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_SourceRapprochementTerritorial"."NomFichierSource" IS 'Nom du fichier justificatif ; privilégier le nom simple plutôt qu’un chemin personnel ou un secret.';

--
-- Name: COLUMN "T_SourceRapprochementTerritorial"."DateSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_SourceRapprochementTerritorial"."DateSource" IS 'Date déclarée dans la source ; NULL si inconnue, distincte de la date d’import.';

--
-- Name: COLUMN "T_SourceRapprochementTerritorial"."MetadonneesSource"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_SourceRapprochementTerritorial"."MetadonneesSource" IS 'Provenance et périmètre de la source en objet JSON, sans géométrie ou coordonnées déduites de mesures de surface/longueur.';

--
-- Name: COLUMN "T_SourceRapprochementTerritorial"."CreeLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_SourceRapprochementTerritorial"."CreeLe" IS 'Instant technique de conservation de la preuve, indépendant de la date des données source.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerrit_ID_SourceRapprochementTerr_not_null" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerrit_ID_SourceRapprochementTerr_not_null" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_CodeSource_not_null" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_CodeSource_not_null" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_VersionSource_not_null" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_VersionSource_not_null" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_not_null" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_not_null" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_NomFichierSource_not_null" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_NomFichierSource_not_null" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_MetadonneesSource_not_null" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_MetadonneesSource_not_null" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_CreeLe_not_null" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_CreeLe_not_null" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_CodeSource_check" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_CodeSource_check" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_MetadonneesSource_check" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_MetadonneesSource_check" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_NomFichierSource_check" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_NomFichierSource_check" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_check" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_check" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_VersionSource_check" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_VersionSource_check" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_SourceRapprochementTerritor_ID_SourceRapprochementTerrito_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_SourceRapprochementTerritorial" ALTER COLUMN "ID_SourceRapprochementTerritorial" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_SourceRapprochementTerritor_ID_SourceRapprochementTerrito_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_SourceRapprochementTerritor_ID_SourceRapprochementTerrito_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_SourceRapprochementTerritor_ID_SourceRapprochementTerrito_seq" IS 'Séquence technique d’identité du rapprochement ; aucun UID externe ou code métier n’est généré par cette séquence.';

--
-- Name: T_CorrespondanceTerritoriale T_CorrespondanceTerritoriale_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CorrespondanceTerritoriale"
    ADD CONSTRAINT "T_CorrespondanceTerritoriale_pkey" PRIMARY KEY ("ID_CorrespondanceTerritoriale");

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_pkey" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_pkey" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_pkey" PRIMARY KEY ("ID_LienTerritorial");

--
-- Name: CONSTRAINT "T_LienTerritorial_pkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_pkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_SourceRapprochementTerritorial T_SourceRapprochementTerritorial_Sha256Source_key; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_SourceRapprochementTerritorial"
    ADD CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_key" UNIQUE ("Sha256Source");

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_key" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_Sha256Source_key" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_SourceRapprochementTerritorial T_SourceRapprochementTerritorial_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_SourceRapprochementTerritorial"
    ADD CONSTRAINT "T_SourceRapprochementTerritorial_pkey" PRIMARY KEY ("ID_SourceRapprochementTerritorial");

--
-- Name: CONSTRAINT "T_SourceRapprochementTerritorial_pkey" ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_SourceRapprochementTerritorial_pkey" ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_CorrespondanceTerritoriale uq_correspondance_source_ligne; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CorrespondanceTerritoriale"
    ADD CONSTRAINT uq_correspondance_source_ligne UNIQUE ("ID_SourceRapprochementFk", "CleLigneSource");

--
-- Name: CONSTRAINT uq_correspondance_source_ligne ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT uq_correspondance_source_ligne ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial uq_lien_territorial_source_ligne; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT uq_lien_territorial_source_ligne UNIQUE ("ID_SourceRapprochementFk", "CleLienSource");

--
-- Name: CONSTRAINT uq_lien_territorial_source_ligne ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT uq_lien_territorial_source_ligne ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: INDEX "T_CorrespondanceTerritoriale_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_CorrespondanceTerritoriale_pkey" IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: INDEX "T_LienTerritorial_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_LienTerritorial_pkey" IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: INDEX "T_SourceRapprochementTerritorial_Sha256Source_key"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_SourceRapprochementTerritorial_Sha256Source_key" IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: INDEX "T_SourceRapprochementTerritorial_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_SourceRapprochementTerritorial_pkey" IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: ix_correspondance_territoire_n1; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX ix_correspondance_territoire_n1 ON geolocalisation."T_CorrespondanceTerritoriale" USING btree ("ID_Niveau_1Fk") WHERE ("ID_Niveau_1Fk" IS NOT NULL);

--
-- Name: INDEX ix_correspondance_territoire_n1; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.ix_correspondance_territoire_n1 IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: ix_correspondance_territoire_n3; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX ix_correspondance_territoire_n3 ON geolocalisation."T_CorrespondanceTerritoriale" USING btree ("ID_Niveau_3Fk") WHERE ("ID_Niveau_3Fk" IS NOT NULL);

--
-- Name: INDEX ix_correspondance_territoire_n3; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.ix_correspondance_territoire_n3 IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: ix_correspondance_territoire_n4; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX ix_correspondance_territoire_n4 ON geolocalisation."T_CorrespondanceTerritoriale" USING btree ("ID_Niveau_4Fk") WHERE ("ID_Niveau_4Fk" IS NOT NULL);

--
-- Name: INDEX ix_correspondance_territoire_n4; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.ix_correspondance_territoire_n4 IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: ix_correspondance_territoire_n5; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX ix_correspondance_territoire_n5 ON geolocalisation."T_CorrespondanceTerritoriale" USING btree ("ID_Niveau_5Fk") WHERE ("ID_Niveau_5Fk" IS NOT NULL);

--
-- Name: INDEX ix_correspondance_territoire_n5; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.ix_correspondance_territoire_n5 IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: ix_correspondance_uid_confirme; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX ix_correspondance_uid_confirme ON geolocalisation."T_CorrespondanceTerritoriale" USING btree ("UidSNISSource") WHERE (("Decision" = 'confirmee'::text) AND ("UidSNISSource" IS NOT NULL));

--
-- Name: INDEX ix_correspondance_uid_confirme; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.ix_correspondance_uid_confirme IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: uq_correspondance_source_grid3id; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_correspondance_source_grid3id ON geolocalisation."T_CorrespondanceTerritoriale" USING btree ("ID_SourceRapprochementFk", "Grid3Id") WHERE ("Grid3Id" IS NOT NULL);

--
-- Name: INDEX uq_correspondance_source_grid3id; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_correspondance_source_grid3id IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: INDEX uq_correspondance_source_ligne; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_correspondance_source_ligne IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: INDEX uq_lien_territorial_source_ligne; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_lien_territorial_source_ligne IS 'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.';

--
-- Name: uq_uid_snis_niveau_1; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_uid_snis_niveau_1 ON geolocalisation."T_Niveau_1" USING btree (btrim("uidSNIS")) WHERE (NULLIF(btrim("uidSNIS"), ''::text) IS NOT NULL);

--
-- Name: INDEX uq_uid_snis_niveau_1; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_uid_snis_niveau_1 IS 'Unicité locale d’un UID SNIS non vide dans ce niveau territorial, casse conservée. Plusieurs NULL restent possibles. Ne garantit pas l’unicité inter-niveaux ni la correspondance avec une source externe.';

--
-- Name: uq_uid_snis_niveau_3; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_uid_snis_niveau_3 ON geolocalisation."T_Niveau_3" USING btree (btrim("uidSNIS")) WHERE (NULLIF(btrim("uidSNIS"), ''::text) IS NOT NULL);

--
-- Name: INDEX uq_uid_snis_niveau_3; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_uid_snis_niveau_3 IS 'Unicité locale d’un UID SNIS non vide dans ce niveau territorial, casse conservée. Plusieurs NULL restent possibles. Ne garantit pas l’unicité inter-niveaux ni la correspondance avec une source externe.';

--
-- Name: uq_uid_snis_niveau_4; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE UNIQUE INDEX uq_uid_snis_niveau_4 ON geolocalisation."T_Niveau_4" USING btree (btrim("uidSNIS")) WHERE (NULLIF(btrim("uidSNIS"), ''::text) IS NOT NULL);

--
-- Name: INDEX uq_uid_snis_niveau_4; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.uq_uid_snis_niveau_4 IS 'Unicité locale d’un UID SNIS non vide dans ce niveau territorial, casse conservée. Plusieurs NULL restent possibles. Ne garantit pas l’unicité inter-niveaux ni la correspondance avec une source externe.';

--
-- Name: T_CorrespondanceTerritoriale rapprochement_territorial_integrite; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER rapprochement_territorial_integrite BEFORE INSERT OR DELETE OR UPDATE ON geolocalisation."T_CorrespondanceTerritoriale" FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_rapprochement_territorial_integrite();

--
-- Name: TRIGGER rapprochement_territorial_integrite ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER rapprochement_territorial_integrite ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Provenance et décisions finales immuables ; contrôles des parents et conflits avant confirmation, sans réécriture des territoires.';

--
-- Name: T_LienTerritorial rapprochement_territorial_integrite; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER rapprochement_territorial_integrite BEFORE INSERT OR DELETE OR UPDATE ON geolocalisation."T_LienTerritorial" FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_rapprochement_territorial_integrite();

--
-- Name: TRIGGER rapprochement_territorial_integrite ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER rapprochement_territorial_integrite ON geolocalisation."T_LienTerritorial" IS 'Provenance et décisions finales immuables ; contrôles des parents et conflits avant confirmation, sans réécriture des territoires.';

--
-- Name: T_SourceRapprochementTerritorial rapprochement_territorial_integrite; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER rapprochement_territorial_integrite BEFORE INSERT OR DELETE OR UPDATE ON geolocalisation."T_SourceRapprochementTerritorial" FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_rapprochement_territorial_integrite();

--
-- Name: TRIGGER rapprochement_territorial_integrite ON "T_SourceRapprochementTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER rapprochement_territorial_integrite ON geolocalisation."T_SourceRapprochementTerritorial" IS 'Provenance et décisions finales immuables ; contrôles des parents et conflits avant confirmation, sans réécriture des territoires.';

--
-- Name: T_Niveau_1 uid_snis_integrite; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER uid_snis_integrite BEFORE INSERT OR UPDATE OF "uidSNIS" ON geolocalisation."T_Niveau_1" FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_uid_snis_integrite();

--
-- Name: TRIGGER uid_snis_integrite ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER uid_snis_integrite ON geolocalisation."T_Niveau_1" IS 'Refuse un nouvel UID SNIS mal formé, conserve les valeurs inchangées et les NULL ; correction explicite toujours possible.';

--
-- Name: T_Niveau_3 uid_snis_integrite; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER uid_snis_integrite BEFORE INSERT OR UPDATE OF "uidSNIS" ON geolocalisation."T_Niveau_3" FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_uid_snis_integrite();

--
-- Name: TRIGGER uid_snis_integrite ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER uid_snis_integrite ON geolocalisation."T_Niveau_3" IS 'Refuse un nouvel UID SNIS mal formé, conserve les valeurs inchangées et les NULL ; correction explicite toujours possible.';

--
-- Name: T_Niveau_4 uid_snis_integrite; Type: TRIGGER; Schema: geolocalisation; Owner: -
--

CREATE TRIGGER uid_snis_integrite BEFORE INSERT OR UPDATE OF "uidSNIS" ON geolocalisation."T_Niveau_4" FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_uid_snis_integrite();

--
-- Name: TRIGGER uid_snis_integrite ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TRIGGER uid_snis_integrite ON geolocalisation."T_Niveau_4" IS 'Refuse un nouvel UID SNIS mal formé, conserve les valeurs inchangées et les NULL ; correction explicite toujours possible.';

--
-- Name: T_CorrespondanceTerritoriale T_CorrespondanceTerritoriale_DecideParUserFk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CorrespondanceTerritoriale"
    ADD CONSTRAINT "T_CorrespondanceTerritoriale_DecideParUserFk_fkey" FOREIGN KEY ("DecideParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_DecideParUserFk_fkey" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_DecideParUserFk_fkey" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_CorrespondanceTerritoriale T_CorrespondanceTerritoriale_ID_Niveau_1Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CorrespondanceTerritoriale"
    ADD CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_1Fk_fkey" FOREIGN KEY ("ID_Niveau_1Fk") REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_1Fk_fkey" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_1Fk_fkey" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_CorrespondanceTerritoriale T_CorrespondanceTerritoriale_ID_Niveau_3Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CorrespondanceTerritoriale"
    ADD CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_3Fk_fkey" FOREIGN KEY ("ID_Niveau_3Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_3Fk_fkey" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_3Fk_fkey" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_CorrespondanceTerritoriale T_CorrespondanceTerritoriale_ID_Niveau_4Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CorrespondanceTerritoriale"
    ADD CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_4Fk_fkey" FOREIGN KEY ("ID_Niveau_4Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_4Fk_fkey" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_4Fk_fkey" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_CorrespondanceTerritoriale T_CorrespondanceTerritoriale_ID_Niveau_5Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CorrespondanceTerritoriale"
    ADD CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_5Fk_fkey" FOREIGN KEY ("ID_Niveau_5Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_5Fk_fkey" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_ID_Niveau_5Fk_fkey" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_CorrespondanceTerritoriale T_CorrespondanceTerritoriale_ID_SourceRapprochementFk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_CorrespondanceTerritoriale"
    ADD CONSTRAINT "T_CorrespondanceTerritoriale_ID_SourceRapprochementFk_fkey" FOREIGN KEY ("ID_SourceRapprochementFk") REFERENCES geolocalisation."T_SourceRapprochementTerritorial"("ID_SourceRapprochementTerritorial") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_CorrespondanceTerritoriale_ID_SourceRapprochementFk_fkey" ON "T_CorrespondanceTerritoriale"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_CorrespondanceTerritoriale_ID_SourceRapprochementFk_fkey" ON geolocalisation."T_CorrespondanceTerritoriale" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_DecideParUserFk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_DecideParUserFk_fkey" FOREIGN KEY ("DecideParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_LienTerritorial_DecideParUserFk_fkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_DecideParUserFk_fkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_ID_CibleNiveau_2Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_2Fk_fkey" FOREIGN KEY ("ID_CibleNiveau_2Fk") REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_2Fk_fkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_2Fk_fkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_ID_CibleNiveau_3Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_3Fk_fkey" FOREIGN KEY ("ID_CibleNiveau_3Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_3Fk_fkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_3Fk_fkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_ID_CibleNiveau_4Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_4Fk_fkey" FOREIGN KEY ("ID_CibleNiveau_4Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_4Fk_fkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_CibleNiveau_4Fk_fkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_ID_OrigineNiveau_3Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_3Fk_fkey" FOREIGN KEY ("ID_OrigineNiveau_3Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_3Fk_fkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_3Fk_fkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_ID_OrigineNiveau_4Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_4Fk_fkey" FOREIGN KEY ("ID_OrigineNiveau_4Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_4Fk_fkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_4Fk_fkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_ID_OrigineNiveau_5Fk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_5Fk_fkey" FOREIGN KEY ("ID_OrigineNiveau_5Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_5Fk_fkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_OrigineNiveau_5Fk_fkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- Name: T_LienTerritorial T_LienTerritorial_ID_SourceRapprochementFk_fkey; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_LienTerritorial"
    ADD CONSTRAINT "T_LienTerritorial_ID_SourceRapprochementFk_fkey" FOREIGN KEY ("ID_SourceRapprochementFk") REFERENCES geolocalisation."T_SourceRapprochementTerritorial"("ID_SourceRapprochementTerritorial") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_LienTerritorial_ID_SourceRapprochementFk_fkey" ON "T_LienTerritorial"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_LienTerritorial_ID_SourceRapprochementFk_fkey" ON geolocalisation."T_LienTerritorial" IS 'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.';

--
-- PostgreSQL database dump complete
--

\unrestrict rX9g7zWSEPHO8mTXfNug0rKiO3i30Wuw6lrfckd5Ak7WyzTnLYTs9Uby5Cprw4x
