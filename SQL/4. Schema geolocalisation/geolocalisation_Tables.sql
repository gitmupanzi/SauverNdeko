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
-- PostgreSQL database dump complete
--

\unrestrict rX9g7zWSEPHO8mTXfNug0rKiO3i30Wuw6lrfckd5Ak7WyzTnLYTs9Uby5Cprw4x
