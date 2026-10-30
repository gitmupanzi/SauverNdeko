-- Extrait canonique du catalogue installé le 30/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_AS_sans_Site; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_AS_sans_Site" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_Niveau_4",
    n4."NomNiveau_4"
   FROM (((((geolocalisation."T_Niveau_4" n4
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n4."ID_Niveau_3_Fk" = n3."ID_Niveau_3")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_5" n5 ON ((n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3", n4."ID_Niveau_4", n4."NomNiveau_4"
 HAVING (count(n5."ID_Niveau_5") = 0);

--
-- Name: VIEW "V_AS_sans_Site"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_AS_sans_Site" IS 'Vue de controle qualite : Aires de Sante (Niveau 4) sans structure ou site (Niveau 5).';

--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';

--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';

--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';

--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';

--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';

--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';

--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';

--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_4" IS 'Identifiant de l’unité géographique de niveau 4. Expression projetée : n4."ID_Niveau_4".';

--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_4" IS 'Nom de l’unité géographique de niveau 4. Expression projetée : n4."NomNiveau_4".';

--
-- Name: V_DestinationLogistique; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_DestinationLogistique" AS
 SELECT n5."ID_Niveau_5" AS id,
    n5."NomNiveau_5",
    n5."CodeNiveau_5",
    concat_ws(' / '::text, NULLIF(btrim((n0."NomNiveau_0")::text), ''::text), NULLIF(btrim((n1."NomNiveau_1")::text), ''::text),
        CASE
            WHEN (NULLIF(btrim((n2."NomNiveau_2")::text), ''::text) IS NOT NULL) THEN concat(COALESCE(NULLIF(btrim((t2."AbrGenerique")::text), ''::text), NULLIF(btrim((t2."NomGenerique")::text), ''::text), 'Niveau 2'::text), ' · ', btrim((n2."NomNiveau_2")::text))
            ELSE NULL::text
        END,
        CASE
            WHEN (NULLIF(btrim((n3."NomNiveau_3")::text), ''::text) IS NOT NULL) THEN concat(COALESCE(NULLIF(btrim((t3."AbrGenerique")::text), ''::text), NULLIF(btrim((t3."NomGenerique")::text), ''::text), 'Niveau 3'::text), ' · ', btrim((n3."NomNiveau_3")::text))
            ELSE NULL::text
        END,
        CASE
            WHEN (NULLIF(btrim((n4."NomNiveau_4")::text), ''::text) IS NOT NULL) THEN concat(COALESCE(NULLIF(btrim((t4."AbrGenerique")::text), ''::text), NULLIF(btrim((t4."NomGenerique")::text), ''::text), 'Niveau 4'::text), ' · ', btrim((n4."NomNiveau_4")::text))
            ELSE NULL::text
        END,
        CASE
            WHEN (NULLIF(btrim((n5."NomNiveau_5")::text), ''::text) IS NOT NULL) THEN concat(COALESCE(NULLIF(btrim((t5."AbrGenerique")::text), ''::text), NULLIF(btrim((t5."NomGenerique")::text), ''::text), 'Niveau 5'::text), ' · ', btrim((n5."NomNiveau_5")::text))
            ELSE NULL::text
        END) AS label,
    n3."ID_Niveau_3" AS "ID_Niveau_3_Fk",
    n4."ID_Niveau_4" AS "ID_Niveau_4_Fk",
    ((NULLIF(btrim((n5."NomNiveau_5")::text), ''::text) IS NOT NULL) AND (n3."ID_Niveau_3" IS NOT NULL) AND (n2."ID_Niveau_2" IS NOT NULL) AND (n1."ID_Niveau_1" IS NOT NULL) AND (n0."ID_Niveau_0" IS NOT NULL) AND ((n5."ID_Niveau_4_Fk" IS NULL) OR (n4."ID_Niveau_4" IS NOT NULL)) AND ((n5."ID_Niveau_3_Fk" IS NULL) OR (n5."ID_Niveau_4_Fk" IS NULL) OR (n5."ID_Niveau_3_Fk" = n4."ID_Niveau_3_Fk"))) AS "EstCoherente"
   FROM (((((((((geolocalisation."T_Niveau_5" n5
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk")))
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n3."ID_Niveau_3" = COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk"))))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n2."ID_Niveau_2" = n3."ID_Niveau_2_FK")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n1."ID_Niveau_1" = n2."ID_Niveau_1_FK")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n0."ID_Niveau_0" = n1."ID_Niveau_0_Fk")))
     LEFT JOIN referentiel."T_Generique" t2 ON ((t2."ID_Generique" = n2."ID_TypeNiveau_2_Fk")))
     LEFT JOIN referentiel."T_Generique" t3 ON ((t3."ID_Generique" = n3."ID_TypeNiveau_2_Fk")))
     LEFT JOIN referentiel."T_Generique" t4 ON ((t4."ID_Generique" = n4."ID_TypeNiveau_4_Fk")))
     LEFT JOIN referentiel."T_Generique" t5 ON ((t5."ID_Generique" = n5."ID_TypeNiveau_5_Fk")));

--
-- Name: VIEW "V_DestinationLogistique"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_DestinationLogistique" IS 'Destinations avec types géographiques et sanitaires issus du référentiel commun ; chemin hiérarchique conservé et cohérence des parents contrôlée.';

--
-- Name: COLUMN "V_DestinationLogistique".id; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_DestinationLogistique".id IS 'Lieu référencé ou chemin géographique existant : id. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_DestinationLogistique"."NomNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_DestinationLogistique"."NomNiveau_5" IS 'Lieu référencé ou chemin géographique existant : NomNiveau_5. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_DestinationLogistique"."CodeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_DestinationLogistique"."CodeNiveau_5" IS 'Lieu référencé ou chemin géographique existant : CodeNiveau_5. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_DestinationLogistique".label; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_DestinationLogistique".label IS 'Chemin hiérarchique : chaque niveau typé porte l’abréviation réelle du référentiel (AS, ZS, etc.), ou son libellé de type ; aucune classification déduite du nom du lieu.';

--
-- Name: COLUMN "V_DestinationLogistique"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_DestinationLogistique"."ID_Niveau_3_Fk" IS 'Lieu référencé ou chemin géographique existant : ID_Niveau_3_Fk. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_DestinationLogistique"."ID_Niveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_DestinationLogistique"."ID_Niveau_4_Fk" IS 'Lieu référencé ou chemin géographique existant : ID_Niveau_4_Fk. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_DestinationLogistique"."EstCoherente"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_DestinationLogistique"."EstCoherente" IS 'Lieu référencé ou chemin géographique existant : EstCoherente. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: V_Niveau_0; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_0" AS
 SELECT "ID_Niveau_0",
    "NomNiveau_0",
    iso,
    "CodeNiveau_0",
    "geometryNiveau_0"
   FROM geolocalisation."T_Niveau_0" n0;

--
-- Name: VIEW "V_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_0" IS 'Vue de reference du Niveau 0 : nom, code et geometrie.';

--
-- Name: COLUMN "V_Niveau_0"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : "ID_Niveau_0".';

--
-- Name: COLUMN "V_Niveau_0"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : "NomNiveau_0".';

--
-- Name: COLUMN "V_Niveau_0"."CodeNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."CodeNiveau_0" IS 'Code de référence de l’unité géographique de niveau 0. Expression projetée : "CodeNiveau_0".';

--
-- Name: COLUMN "V_Niveau_0"."geometryNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."geometryNiveau_0" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 0. Expression projetée : "geometryNiveau_0".';

--
-- Name: V_Niveau_1; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_1" AS
 SELECT n1a."ID_Niveau_0_Fk",
    n0."NomNiveau_0",
    n1a."ID_Niveau_1_Old_Fk",
    n1b."NomNiveau_1_Old",
    n1a."ID_Niveau_1",
    n1a."NomNiveau_1",
    n1a."Alt1_Niveau_1",
    n1a."Alt2_Niveau_1",
    n1a."AbreNiveau_1",
    n1a."CodeSNIS",
    n1a."CodeNiveau_1",
    n1a."PopulationNiveau_1",
    n1a."LatitudeNiveau_1",
    n1a."LongitudeNiveau_1",
    n1a."surfaceNiveau_1",
    n1a."geometryNiveau_1",
    n1a."EtenduNiveau_1",
    n1a."timezoneNiveau_1",
    n1a."wikidataNiveau_1",
    n1a."FusionNiveau_1",
    n1a."VisibleNiveau_1",
    n1a."VisibleNiveau_5",
    n1a."ObsNiveau_1"
   FROM ((geolocalisation."T_Niveau_1" n1a
     LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON ((n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")));

--
-- Name: VIEW "V_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_1" IS 'Vue de reference du Niveau 1 avec rattachement au Niveau 0 et a l''ancien Niveau 1.';

--
-- Name: COLUMN "V_Niveau_1"."ID_Niveau_0_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."ID_Niveau_0_Fk" IS 'Unité géographique de rattachement de niveau 0. Expression projetée : n1a."ID_Niveau_0_Fk".';

--
-- Name: COLUMN "V_Niveau_1"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_Niveau_1"."ID_Niveau_1_Old_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."ID_Niveau_1_Old_Fk" IS 'Unité géographique de rattachement de niveau 1_Old. Expression projetée : n1a."ID_Niveau_1_Old_Fk".';

--
-- Name: COLUMN "V_Niveau_1"."NomNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."NomNiveau_1_Old" IS 'Nom de l’unité géographique de niveau 1 historique. Expression projetée : n1b."NomNiveau_1_Old".';

--
-- Name: COLUMN "V_Niveau_1"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1a."ID_Niveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1a."NomNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."Alt1_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."Alt1_Niveau_1" IS 'Première appellation alternative de l’unité de niveau 1. Expression projetée : n1a."Alt1_Niveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."Alt2_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."Alt2_Niveau_1" IS 'Deuxième appellation alternative de l’unité de niveau 1. Expression projetée : n1a."Alt2_Niveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."AbreNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."AbreNiveau_1" IS 'Abréviation de l’unité géographique de niveau 1. Expression projetée : n1a."AbreNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."CodeSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."CodeSNIS" IS 'Code SNIS enregistré pour l’unité géographique de niveau 1. Expression projetée : n1a."CodeSNIS".';

--
-- Name: COLUMN "V_Niveau_1"."CodeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."CodeNiveau_1" IS 'Code de référence de l’unité géographique de niveau 1. Expression projetée : n1a."CodeNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."PopulationNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."PopulationNiveau_1" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 1. Expression projetée : n1a."PopulationNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."LatitudeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."LatitudeNiveau_1" IS 'Latitude enregistrée pour l’unité géographique de niveau 1. Expression projetée : n1a."LatitudeNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."LongitudeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."LongitudeNiveau_1" IS 'Longitude enregistrée pour l’unité géographique de niveau 1. Expression projetée : n1a."LongitudeNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."surfaceNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."surfaceNiveau_1" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 1. Expression projetée : n1a."surfaceNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."geometryNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."geometryNiveau_1" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 1. Expression projetée : n1a."geometryNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."EtenduNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."EtenduNiveau_1" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 1. Expression projetée : n1a."EtenduNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."timezoneNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."timezoneNiveau_1" IS 'Fuseau horaire déclaré pour l’unité de niveau 1. Expression projetée : n1a."timezoneNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."wikidataNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."wikidataNiveau_1" IS 'Référence Wikidata déclarée pour l’unité de niveau 1. Expression projetée : n1a."wikidataNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."FusionNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."FusionNiveau_1" IS 'Indicateur de fusion enregistré pour l’unité de niveau 1. Expression projetée : n1a."FusionNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."VisibleNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."VisibleNiveau_1" IS 'Indicateur de visibilité pour le niveau géographique de niveau 1. Expression projetée : n1a."VisibleNiveau_1".';

--
-- Name: COLUMN "V_Niveau_1"."VisibleNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5. Expression projetée : n1a."VisibleNiveau_5".';

--
-- Name: COLUMN "V_Niveau_1"."ObsNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."ObsNiveau_1" IS 'Observations sur l’unité géographique de niveau 1. Expression projetée : n1a."ObsNiveau_1".';

--
-- Name: V_Niveau_1_Old; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_1_Old" AS
 SELECT "ID_Niveau_1_Old",
    "NomNiveau_1_Old",
    "geometryNiveau_1_Old",
    "surfaceNiveau_1_Old"
   FROM geolocalisation."T_Niveau_1_Old" n1o;

--
-- Name: VIEW "V_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_1_Old" IS 'Vue de reference de l''ancien Niveau 1 pour les correspondances historiques.';

--
-- Name: COLUMN "V_Niveau_1_Old"."ID_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1_Old"."ID_Niveau_1_Old" IS 'Identifiant de l’unité géographique de niveau 1 historique. Expression projetée : "ID_Niveau_1_Old".';

--
-- Name: COLUMN "V_Niveau_1_Old"."NomNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1_Old"."NomNiveau_1_Old" IS 'Nom de l’unité géographique de niveau 1 historique. Expression projetée : "NomNiveau_1_Old".';

--
-- Name: COLUMN "V_Niveau_1_Old"."geometryNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1_Old"."geometryNiveau_1_Old" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 1 historique. Expression projetée : "geometryNiveau_1_Old".';

--
-- Name: COLUMN "V_Niveau_1_Old"."surfaceNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1_Old"."surfaceNiveau_1_Old" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 1 historique. Expression projetée : "surfaceNiveau_1_Old".';

--
-- Name: V_Niveau_2; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_2" AS
 SELECT n0."NomNiveau_0",
    n1b."NomNiveau_1_Old",
    n2."ID_Niveau_1_FK",
    n1a."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."ID_TypeNiveau_2_Fk",
    COALESCE(g_type."AbrGenerique", ' '::character varying) AS "Type_Niveau_2",
    n2."NomNiveau_2",
    n2."Alt1_NomNiveau_2",
    n2."AbreNiveau_2",
    n2."CodeNiveau_2",
    n2."PopulationNiveau_2",
    n2."LatitudeNiveau_2",
    n2."LongitudeNiveau_2",
    n2."AltitudeNiveau_2",
    n2."geometryNiveau_2",
    n2."surfaceNiveau_2",
    n2."EtenduNiveau_2",
    n2."ObsNiveau_2",
    n2."ID_StatutNiveau_2",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "Statut_Niveau_2",
    n2."ID_StatusDeploiFk",
    COALESCE(g_deploi."AbrGenerique", ' '::character varying) AS "Statut_Deploiement",
    n2."KmDPSANT",
    n2."ID_VoieAccesDPSANTFk",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "Voie_Acces_DPS",
    n2."SelectNiveau_2"
   FROM (((((((geolocalisation."T_Niveau_2" n2
     LEFT JOIN geolocalisation."T_Niveau_1" n1a ON ((n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON ((n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n2."ID_TypeNiveau_2_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n2."ID_StatutNiveau_2" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploi ON ((n2."ID_StatusDeploiFk" = g_deploi."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n2."ID_VoieAccesDPSANTFk" = g_voie."ID_Generique")));

--
-- Name: VIEW "V_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_2" IS 'Vue de reference du Niveau 2 avec contexte hierarchique, type, statut, deploiement et voie d''acces.';

--
-- Name: COLUMN "V_Niveau_2"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_Niveau_2"."NomNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."NomNiveau_1_Old" IS 'Nom de l’unité géographique de niveau 1 historique. Expression projetée : n1b."NomNiveau_1_Old".';

--
-- Name: COLUMN "V_Niveau_2"."ID_Niveau_1_FK"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_1_FK" IS 'Unité géographique de rattachement de niveau 1. Expression projetée : n2."ID_Niveau_1_FK".';

--
-- Name: COLUMN "V_Niveau_2"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1a."NomNiveau_1".';

--
-- Name: COLUMN "V_Niveau_2"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n2."ID_TypeNiveau_2_Fk".';

--
-- Name: COLUMN "V_Niveau_2"."Type_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Type_Niveau_2" IS 'Abréviation du type d’unité de niveau 2 dans le référentiel. Expression projetée : COALESCE(g_type."AbrGenerique", '' ''::character varying) AS "Type_Niveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."Alt1_NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Alt1_NomNiveau_2" IS 'Appellation alternative de l’unité de niveau 2. Expression projetée : n2."Alt1_NomNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."AbreNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."AbreNiveau_2" IS 'Abréviation de l’unité géographique de niveau 2. Expression projetée : n2."AbreNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."CodeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."CodeNiveau_2" IS 'Code de référence de l’unité géographique de niveau 2. Expression projetée : n2."CodeNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."PopulationNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."PopulationNiveau_2" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 2. Expression projetée : n2."PopulationNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."LatitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."LatitudeNiveau_2" IS 'Latitude enregistrée pour l’unité géographique de niveau 2. Expression projetée : n2."LatitudeNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."LongitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."LongitudeNiveau_2" IS 'Longitude enregistrée pour l’unité géographique de niveau 2. Expression projetée : n2."LongitudeNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."AltitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."AltitudeNiveau_2" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 2. Expression projetée : n2."AltitudeNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."geometryNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."geometryNiveau_2" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 2. Expression projetée : n2."geometryNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."surfaceNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."surfaceNiveau_2" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 2. Expression projetée : n2."surfaceNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."EtenduNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."EtenduNiveau_2" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 2. Expression projetée : n2."EtenduNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."ObsNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ObsNiveau_2" IS 'Observations sur l’unité géographique de niveau 2. Expression projetée : n2."ObsNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."ID_StatutNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_StatutNiveau_2" IS 'Statut de l’unité géographique dans le référentiel. Expression projetée : n2."ID_StatutNiveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."Statut_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Statut_Niveau_2" IS 'Abréviation du statut de l’unité de niveau 2. Expression projetée : COALESCE(g_statut."AbrGenerique", '' ''::character varying) AS "Statut_Niveau_2".';

--
-- Name: COLUMN "V_Niveau_2"."ID_StatusDeploiFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_StatusDeploiFk" IS 'Statut de déploiement enregistré pour l’unité de niveau 2. Expression projetée : n2."ID_StatusDeploiFk".';

--
-- Name: COLUMN "V_Niveau_2"."Statut_Deploiement"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Statut_Deploiement" IS 'Abréviation du statut de déploiement issu du référentiel. Expression projetée : COALESCE(g_deploi."AbrGenerique", '' ''::character varying) AS "Statut_Deploiement".';

--
-- Name: COLUMN "V_Niveau_2"."KmDPSANT"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."KmDPSANT" IS 'Distance enregistrée entre la DPS et l’antenne, en kilomètres. Expression projetée : n2."KmDPSANT".';

--
-- Name: COLUMN "V_Niveau_2"."ID_VoieAccesDPSANTFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_VoieAccesDPSANTFk" IS 'Voie d’accès entre la DPS et l’antenne. Expression projetée : n2."ID_VoieAccesDPSANTFk".';

--
-- Name: COLUMN "V_Niveau_2"."Voie_Acces_DPS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Voie_Acces_DPS" IS 'Abréviation de la voie d’accès DPS/antenne. Expression projetée : COALESCE(g_voie."AbrGenerique", '' ''::character varying) AS "Voie_Acces_DPS".';

--
-- Name: COLUMN "V_Niveau_2"."SelectNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."SelectNiveau_2" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 2. Expression projetée : n2."SelectNiveau_2".';

--
-- Name: V_Niveau_3; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_3" AS
 SELECT n3."ID_TypeNiveau_2_Fk",
    COALESCE(g_type."AbrGenerique", ' '::character varying) AS "Type_Niveau_3",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n3."Alt_Niveau_3",
    n3."AbreNiveau_3",
    n3."CodeNiveau_3",
    n3."LatitudeNiveau_3",
    n3."PopulationNiveau_3",
    n3."LongitudeNiveau_3",
    n3."AltitudeNiveau_3",
    n3."EtenduNiveau_3",
    n3."surfaceNiveau_3",
    n3."geometryNiveau_3",
    n3."ObsNiveau_3",
    n3."ID_StatutNiveau_3_Fk",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "Statut_Niveau_3",
    n3."ID_StatutDeploieFk",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "Statut_Deploiement",
    n3."KmAntenneBCZS",
    n3."ID_VoieAccesANTBCZFk",
    COALESCE(g_voie1."AbrGenerique", ' '::character varying) AS "Voie_ANTBCZ",
    n3."KmDPSBCZS",
    n3."ID_VoieAccesDPSBCZFk",
    COALESCE(g_voie2."AbrGenerique", ' '::character varying) AS "Voie_DPSBCZS",
    n3."SelectNiveau_3",
    n3."ID_Niveau_2_FK"
   FROM ((((((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1a ON ((n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n3."ID_TypeNiveau_2_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n3."ID_StatutNiveau_3_Fk" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n3."ID_StatutDeploieFk" = g_deploiement."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie1 ON ((n3."ID_VoieAccesANTBCZFk" = g_voie1."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie2 ON ((n3."ID_VoieAccesDPSBCZFk" = g_voie2."ID_Generique")));

--
-- Name: VIEW "V_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_3" IS 'Vue de reference du Niveau 3 avec type, statut, deploiement, distances et voies d''acces.';

--
-- Name: COLUMN "V_Niveau_3"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n3."ID_TypeNiveau_2_Fk".';

--
-- Name: COLUMN "V_Niveau_3"."Type_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Type_Niveau_3" IS 'Abréviation du type d’unité de niveau 3 dans le référentiel. Expression projetée : COALESCE(g_type."AbrGenerique", '' ''::character varying) AS "Type_Niveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."Alt_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Alt_Niveau_3" IS 'Appellation alternative de l’unité de niveau 3. Expression projetée : n3."Alt_Niveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."AbreNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."AbreNiveau_3" IS 'Abréviation de l’unité géographique de niveau 3. Expression projetée : n3."AbreNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."CodeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."CodeNiveau_3" IS 'Code de référence de l’unité géographique de niveau 3. Expression projetée : n3."CodeNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."LatitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."LatitudeNiveau_3" IS 'Latitude enregistrée pour l’unité géographique de niveau 3. Expression projetée : n3."LatitudeNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."PopulationNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."PopulationNiveau_3" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 3. Expression projetée : n3."PopulationNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."LongitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."LongitudeNiveau_3" IS 'Longitude enregistrée pour l’unité géographique de niveau 3. Expression projetée : n3."LongitudeNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."AltitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."AltitudeNiveau_3" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 3. Expression projetée : n3."AltitudeNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."EtenduNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."EtenduNiveau_3" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 3. Expression projetée : n3."EtenduNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."surfaceNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."surfaceNiveau_3" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 3. Expression projetée : n3."surfaceNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."geometryNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."geometryNiveau_3" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 3. Expression projetée : n3."geometryNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."ObsNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ObsNiveau_3" IS 'Observations sur l’unité géographique de niveau 3. Expression projetée : n3."ObsNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."ID_StatutNiveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_StatutNiveau_3_Fk" IS 'Statut de l’unité géographique dans le référentiel. Expression projetée : n3."ID_StatutNiveau_3_Fk".';

--
-- Name: COLUMN "V_Niveau_3"."Statut_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Statut_Niveau_3" IS 'Abréviation du statut de l’unité de niveau 3. Expression projetée : COALESCE(g_statut."AbrGenerique", '' ''::character varying) AS "Statut_Niveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."ID_StatutDeploieFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_StatutDeploieFk" IS 'Statut de déploiement enregistré pour l’unité de niveau 3. Expression projetée : n3."ID_StatutDeploieFk".';

--
-- Name: COLUMN "V_Niveau_3"."Statut_Deploiement"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Statut_Deploiement" IS 'Abréviation du statut de déploiement issu du référentiel. Expression projetée : COALESCE(g_deploiement."AbrGenerique", '' ''::character varying) AS "Statut_Deploiement".';

--
-- Name: COLUMN "V_Niveau_3"."KmAntenneBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."KmAntenneBCZS" IS 'Distance enregistrée entre l’antenne et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmAntenneBCZS".';

--
-- Name: COLUMN "V_Niveau_3"."ID_VoieAccesANTBCZFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_VoieAccesANTBCZFk" IS 'Voie d’accès entre l’antenne et le bureau central de zone de santé. Expression projetée : n3."ID_VoieAccesANTBCZFk".';

--
-- Name: COLUMN "V_Niveau_3"."Voie_ANTBCZ"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Voie_ANTBCZ" IS 'Abréviation de la voie d’accès antenne/bureau central de zone. Expression projetée : COALESCE(g_voie1."AbrGenerique", '' ''::character varying) AS "Voie_ANTBCZ".';

--
-- Name: COLUMN "V_Niveau_3"."KmDPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."KmDPSBCZS" IS 'Distance enregistrée entre la DPS et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmDPSBCZS".';

--
-- Name: COLUMN "V_Niveau_3"."ID_VoieAccesDPSBCZFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_VoieAccesDPSBCZFk" IS 'Voie d’accès entre la DPS et le bureau central de zone de santé. Expression projetée : n3."ID_VoieAccesDPSBCZFk".';

--
-- Name: COLUMN "V_Niveau_3"."Voie_DPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Voie_DPSBCZS" IS 'Abréviation de la voie d’accès DPS/bureau central de zone. Expression projetée : COALESCE(g_voie2."AbrGenerique", '' ''::character varying) AS "Voie_DPSBCZS".';

--
-- Name: COLUMN "V_Niveau_3"."SelectNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."SelectNiveau_3" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 3. Expression projetée : n3."SelectNiveau_3".';

--
-- Name: COLUMN "V_Niveau_3"."ID_Niveau_2_FK"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_2_FK" IS 'Unité géographique de rattachement de niveau 2. Expression projetée : n3."ID_Niveau_2_FK".';

--
-- Name: V_Niveau_4; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_4" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_TypeNiveau_4_Fk",
    COALESCE(g_type."AbrGenerique", ''::character varying) AS "Type_Niveau_4",
    n4."AbreNiveau_4",
    (((COALESCE(g_type."AbrGenerique", ''::character varying))::text || ' '::text) || (COALESCE(n4."NomNiveau_4", ''::character varying))::text) AS "SITE",
    n4."CodeNiveau_4",
    n4."PopulationNiveau_4",
    n4."LatitudeNiveau_4",
    n4."LongitudeNiveau_4",
    n4."AltitudeNiveau_4",
    n4."geometryNiveau_4",
    COALESCE(g_reseau."AbrGenerique", ' '::character varying) AS "RESEAU",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "VOIE_AS_ZS",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "STATUT_AS",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "STATUT_DEPLOI",
    n3."KmAntenneBCZS",
    n3."KmDPSBCZS",
    n4."ObsNiveau_4",
    n4."SelectNiveau_4",
    n4."ID_Niveau_4",
    n4."ID_Niveau_3_Fk",
    n4."NomNiveau_4",
    n4."KmZoneSanteAS",
    n4."surfaceNiveau_4",
    n4."ID_DispoReseauNiveau_4",
    n4."ID_VoieAccesZsASFk",
    n4."ID_StatutNiveau_4",
    n4."ID_StatutDeploiementFk"
   FROM (((((((((geolocalisation."T_Niveau_4" n4
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n4."ID_Niveau_3_Fk" = n3."ID_Niveau_3")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n4."ID_TypeNiveau_4_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n4."ID_VoieAccesZsASFk" = g_voie."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n4."ID_StatutNiveau_4" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n4."ID_StatutDeploiementFk" = g_deploiement."ID_Generique")))
  ORDER BY n0."NomNiveau_0", n1."NomNiveau_1", n2."NomNiveau_2", n3."NomNiveau_3", n4."NomNiveau_4";

--
-- Name: VIEW "V_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_4" IS 'Vue de reference du Niveau 4 avec hierarchie complete, identifiant de ligne, nom brut et indicateurs reseau/statut.';

--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';

--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';

--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';

--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';

--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';

--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';

--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';

--
-- Name: COLUMN "V_Niveau_4"."ID_TypeNiveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_TypeNiveau_4_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n4."ID_TypeNiveau_4_Fk".';

--
-- Name: COLUMN "V_Niveau_4"."Type_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."Type_Niveau_4" IS 'Abréviation du type d’unité de niveau 4 dans le référentiel. Expression projetée : COALESCE(g_type."AbrGenerique", ''''::character varying) AS "Type_Niveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."AbreNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AbreNiveau_4" IS 'Abréviation de l’unité géographique de niveau 4. Expression projetée : n4."AbreNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."SITE"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."SITE" IS 'Libellé de présentation composé de l’abréviation du type et du nom brut de l’unité ; ne remplace pas l’identifiant. Expression projetée : (COALESCE(g_type."AbrGenerique", ''''::character varying)::text || '' ''::text) || COALESCE(n4."NomNiveau_4", ''''::character varying)::text AS "SITE".';

--
-- Name: COLUMN "V_Niveau_4"."CodeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."CodeNiveau_4" IS 'Code de référence de l’unité géographique de niveau 4. Expression projetée : n4."CodeNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."PopulationNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."PopulationNiveau_4" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 4. Expression projetée : n4."PopulationNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."LatitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."LatitudeNiveau_4" IS 'Latitude enregistrée pour l’unité géographique de niveau 4. Expression projetée : n4."LatitudeNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."LongitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."LongitudeNiveau_4" IS 'Longitude enregistrée pour l’unité géographique de niveau 4. Expression projetée : n4."LongitudeNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."AltitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AltitudeNiveau_4" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 4. Expression projetée : n4."AltitudeNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."geometryNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."geometryNiveau_4" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 4. Expression projetée : n4."geometryNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."RESEAU"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."RESEAU" IS 'Abréviation du statut de disponibilité réseau issu du référentiel. Expression projetée : COALESCE(g_reseau."AbrGenerique", '' ''::character varying) AS "RESEAU".';

--
-- Name: COLUMN "V_Niveau_4"."VOIE_AS_ZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."VOIE_AS_ZS" IS 'Abréviation de la voie d’accès entre aire et zone de santé. Expression projetée : COALESCE(g_voie."AbrGenerique", '' ''::character varying) AS "VOIE_AS_ZS".';

--
-- Name: COLUMN "V_Niveau_4"."STATUT_AS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."STATUT_AS" IS 'Abréviation du statut de l’aire de santé. Expression projetée : COALESCE(g_statut."AbrGenerique", '' ''::character varying) AS "STATUT_AS".';

--
-- Name: COLUMN "V_Niveau_4"."STATUT_DEPLOI"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."STATUT_DEPLOI" IS 'Abréviation du statut de déploiement issu du référentiel. Expression projetée : COALESCE(g_deploiement."AbrGenerique", '' ''::character varying) AS "STATUT_DEPLOI".';

--
-- Name: COLUMN "V_Niveau_4"."KmAntenneBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."KmAntenneBCZS" IS 'Distance enregistrée entre l’antenne et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmAntenneBCZS".';

--
-- Name: COLUMN "V_Niveau_4"."KmDPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."KmDPSBCZS" IS 'Distance enregistrée entre la DPS et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmDPSBCZS".';

--
-- Name: COLUMN "V_Niveau_4"."ObsNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ObsNiveau_4" IS 'Observations sur l’unité géographique de niveau 4. Expression projetée : n4."ObsNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."SelectNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."SelectNiveau_4" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 4. Expression projetée : n4."SelectNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_4" IS 'Identifiant de l’unité géographique de niveau 4. Expression projetée : n4."ID_Niveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Expression projetée : n4."ID_Niveau_3_Fk".';

--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_4" IS 'Nom de l’unité géographique de niveau 4. Expression projetée : n4."NomNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."KmZoneSanteAS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."KmZoneSanteAS" IS 'Distance enregistrée entre la zone de santé et l’aire de santé, en kilomètres. Expression projetée : n4."KmZoneSanteAS".';

--
-- Name: COLUMN "V_Niveau_4"."surfaceNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."surfaceNiveau_4" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 4. Expression projetée : n4."surfaceNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."ID_DispoReseauNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_DispoReseauNiveau_4" IS 'Disponibilité du réseau déclarée pour l’unité géographique, dans le référentiel. Expression projetée : n4."ID_DispoReseauNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."ID_VoieAccesZsASFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_VoieAccesZsASFk" IS 'Voie d’accès entre la zone de santé et l’aire de santé. Expression projetée : n4."ID_VoieAccesZsASFk".';

--
-- Name: COLUMN "V_Niveau_4"."ID_StatutNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_StatutNiveau_4" IS 'Statut de l’unité géographique dans le référentiel. Expression projetée : n4."ID_StatutNiveau_4".';

--
-- Name: COLUMN "V_Niveau_4"."ID_StatutDeploiementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_StatutDeploiementFk" IS 'Statut de déploiement enregistré pour l’unité géographique. Expression projetée : n4."ID_StatutDeploiementFk".';

--
-- Name: V_Niveau_5; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_5" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n5."ID_TypeNiveau_5_Fk",
    COALESCE(g_type."AbrGenerique", ''::character varying) AS "Type_Niveau_5",
    (((COALESCE(g_type."AbrGenerique", ''::character varying))::text || ' '::text) || (COALESCE(n5."NomNiveau_5", ''::character varying))::text) AS "SITE",
    n5."AbreNiveau_5",
    n5."CodeNiveau_5",
    n5."PopulationNiveau_5",
    n5."LongitudeNiveau_5",
    n5."LatitudeNiveau_5",
    n5."AltitudeNiveau_5",
    n5."geometryNiveau_5",
    COALESCE(g_reseau."AbrGenerique", ' '::character varying) AS "RESEAU",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "VOIE_AS_Site",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "STATUT_Site",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "STATUT_DEPLOI",
    n3."KmAntenneBCZS",
    n3."KmDPSBCZS",
    n4."ID_Niveau_4",
    n5."ID_Niveau_5",
    n5."ID_Niveau_4_Fk",
    n5."ID_Niveau_3_Fk",
    n5."NomNiveau_5",
    n5."KmZoneSanteNiveau_5",
    n5."surfaceNiveau_5",
    n5."ID_DispoReseauNiveau_5",
    n5."ID_VoieAccesZsSiteFk",
    n5."ID_StatutNiveau_5",
    n5."ID_StatutDeploiementFk",
    n5."ID_TypeToitFk",
    n5."ObsNiveau_5",
    n5."SelectNiveau_5"
   FROM ((((((((((geolocalisation."T_Niveau_5" n5
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n5."ID_Niveau_4_Fk" = n4."ID_Niveau_4")))
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk") = n3."ID_Niveau_3")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n5."ID_TypeNiveau_5_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n5."ID_DispoReseauNiveau_5" = g_reseau."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n5."ID_VoieAccesZsSiteFk" = g_voie."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n5."ID_StatutNiveau_5" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n5."ID_StatutDeploiementFk" = g_deploiement."ID_Generique")))
  ORDER BY n0."NomNiveau_0", n1."NomNiveau_1", n2."NomNiveau_2", n3."NomNiveau_3", n5."NomNiveau_5";

--
-- Name: VIEW "V_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_5" IS 'Vue de reference du Niveau 5 avec identifiants de ligne, nom brut, reseau, statut et informations de site.';

--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';

--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';

--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';

--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';

--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';

--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';

--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';

--
-- Name: COLUMN "V_Niveau_5"."ID_TypeNiveau_5_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n5."ID_TypeNiveau_5_Fk".';

--
-- Name: COLUMN "V_Niveau_5"."Type_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."Type_Niveau_5" IS 'Abréviation du type d’unité de niveau 5 dans le référentiel. Expression projetée : COALESCE(g_type."AbrGenerique", ''''::character varying) AS "Type_Niveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."SITE"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."SITE" IS 'Libellé de présentation composé de l’abréviation du type et du nom brut de l’unité ; ne remplace pas l’identifiant. Expression projetée : (COALESCE(g_type."AbrGenerique", ''''::character varying)::text || '' ''::text) || COALESCE(n5."NomNiveau_5", ''''::character varying)::text AS "SITE".';

--
-- Name: COLUMN "V_Niveau_5"."AbreNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."AbreNiveau_5" IS 'Abréviation de l’unité géographique de niveau 5. Expression projetée : n5."AbreNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."CodeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."CodeNiveau_5" IS 'Code de référence de l’unité géographique de niveau 5. Expression projetée : n5."CodeNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."PopulationNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."PopulationNiveau_5" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 5. Expression projetée : n5."PopulationNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."LongitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."LongitudeNiveau_5" IS 'Longitude enregistrée pour l’unité géographique de niveau 5. Expression projetée : n5."LongitudeNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."LatitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."LatitudeNiveau_5" IS 'Latitude enregistrée pour l’unité géographique de niveau 5. Expression projetée : n5."LatitudeNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."AltitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."AltitudeNiveau_5" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 5. Expression projetée : n5."AltitudeNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."geometryNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."geometryNiveau_5" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 5. Expression projetée : n5."geometryNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."RESEAU"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."RESEAU" IS 'Abréviation du statut de disponibilité réseau issu du référentiel. Expression projetée : COALESCE(g_reseau."AbrGenerique", '' ''::character varying) AS "RESEAU".';

--
-- Name: COLUMN "V_Niveau_5"."VOIE_AS_Site"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."VOIE_AS_Site" IS 'Abréviation de la voie d’accès zone/site selon le rattachement enregistré. Expression projetée : COALESCE(g_voie."AbrGenerique", '' ''::character varying) AS "VOIE_AS_Site".';

--
-- Name: COLUMN "V_Niveau_5"."STATUT_Site"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."STATUT_Site" IS 'Abréviation du statut du site. Expression projetée : COALESCE(g_statut."AbrGenerique", '' ''::character varying) AS "STATUT_Site".';

--
-- Name: COLUMN "V_Niveau_5"."STATUT_DEPLOI"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."STATUT_DEPLOI" IS 'Abréviation du statut de déploiement issu du référentiel. Expression projetée : COALESCE(g_deploiement."AbrGenerique", '' ''::character varying) AS "STATUT_DEPLOI".';

--
-- Name: COLUMN "V_Niveau_5"."KmAntenneBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."KmAntenneBCZS" IS 'Distance enregistrée entre l’antenne et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmAntenneBCZS".';

--
-- Name: COLUMN "V_Niveau_5"."KmDPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."KmDPSBCZS" IS 'Distance enregistrée entre la DPS et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmDPSBCZS".';

--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_4" IS 'Identifiant de l’unité géographique de niveau 4. Expression projetée : n4."ID_Niveau_4".';

--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_5" IS 'Identifiant de l’unité géographique de niveau 5. Expression projetée : n5."ID_Niveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Expression projetée : n5."ID_Niveau_4_Fk".';

--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Expression projetée : n5."ID_Niveau_3_Fk".';

--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_5" IS 'Nom de l’unité géographique de niveau 5. Expression projetée : n5."NomNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."KmZoneSanteNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."KmZoneSanteNiveau_5" IS 'Distance enregistrée entre la zone de santé et le site, en kilomètres. Expression projetée : n5."KmZoneSanteNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."surfaceNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."surfaceNiveau_5" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 5. Expression projetée : n5."surfaceNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."ID_DispoReseauNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_DispoReseauNiveau_5" IS 'Disponibilité du réseau déclarée pour l’unité géographique, dans le référentiel. Expression projetée : n5."ID_DispoReseauNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."ID_VoieAccesZsSiteFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_VoieAccesZsSiteFk" IS 'Voie d’accès entre la zone de santé et le site. Expression projetée : n5."ID_VoieAccesZsSiteFk".';

--
-- Name: COLUMN "V_Niveau_5"."ID_StatutNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_StatutNiveau_5" IS 'Statut de l’unité géographique dans le référentiel. Expression projetée : n5."ID_StatutNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."ID_StatutDeploiementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_StatutDeploiementFk" IS 'Statut de déploiement enregistré pour l’unité géographique. Expression projetée : n5."ID_StatutDeploiementFk".';

--
-- Name: COLUMN "V_Niveau_5"."ID_TypeToitFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_TypeToitFk" IS 'Type de toiture du site, issu du référentiel. Expression projetée : n5."ID_TypeToitFk".';

--
-- Name: COLUMN "V_Niveau_5"."ObsNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ObsNiveau_5" IS 'Observations sur l’unité géographique de niveau 5. Expression projetée : n5."ObsNiveau_5".';

--
-- Name: COLUMN "V_Niveau_5"."SelectNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."SelectNiveau_5" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 5. Expression projetée : n5."SelectNiveau_5".';

--
-- Name: V_Pop_N3_Couverte_Sites; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Pop_N3_Couverte_Sites" AS
 WITH sites AS (
         SELECT n5."ID_Niveau_5",
            n5."ID_Niveau_4_Fk",
            n5."ID_Niveau_3_Fk",
            n5."ID_TypeNiveau_5_Fk",
            n5."NomNiveau_5",
            n5."AbreNiveau_5",
            n5."CodeNiveau_5",
            n5."PopulationNiveau_5",
            n5."surfaceNiveau_5",
            n5."geometryNiveau_5",
            n5."ID_DispoReseauNiveau_5",
            n5."ID_VoieAccesZsSiteFk",
            n5."ID_StatutNiveau_5",
            n5."ID_StatutDeploiementFk",
            n5."ObsNiveau_5",
            n5."SelectNiveau_5",
            n5."ID_TypeToitFk",
            n5."KmZoneSanteNiveau_5",
            n5."LatitudeNiveau_5",
            n5."LongitudeNiveau_5",
            n5."AltitudeNiveau_5",
            COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk") AS region
           FROM (geolocalisation."T_Niveau_5" n5
             LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk")))
        )
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    s."ID_TypeNiveau_5_Fk",
    COALESCE(g."AbrGenerique", ' '::character varying) AS "Type_Niveau_5",
    sum(COALESCE(s."PopulationNiveau_5", (0)::numeric)) AS "Pop_Cum_Sites"
   FROM (((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n2."ID_Niveau_2" = n3."ID_Niveau_2_FK")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n1."ID_Niveau_1" = n2."ID_Niveau_1_FK")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n0."ID_Niveau_0" = n1."ID_Niveau_0_Fk")))
     LEFT JOIN sites s ON ((s.region = n3."ID_Niveau_3")))
     LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = s."ID_TypeNiveau_5_Fk")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3", s."ID_TypeNiveau_5_Fk", g."AbrGenerique";

--
-- Name: VIEW "V_Pop_N3_Couverte_Sites"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Pop_N3_Couverte_Sites" IS 'Population déclarée des sites par niveau 3 et type de site. Inclut le rattachement direct au niveau 3 et le repli par le niveau 4, comme V_Niveau_5 ; chaque site contribue une seule fois. Les populations absentes restent coalescées à zéro selon le contrat historique ; ce total ne prouve pas une couverture démographique sans chevauchement.';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_TypeNiveau_5_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n5."ID_TypeNiveau_5_Fk".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."Type_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."Type_Niveau_5" IS 'Abréviation du type d’unité de niveau 5 dans le référentiel. Expression projetée : COALESCE(g_type5."AbrGenerique", '' ''::character varying) AS "Type_Niveau_5".';

--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."Pop_Cum_Sites"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."Pop_Cum_Sites" IS 'Somme des populations déclarées des sites du groupe, avec rattachement direct au niveau 3 ou via le niveau 4 ; absence coalescée à zéro selon le contrat existant.';

--
-- Name: V_RESEAU_AS_par_ZS; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_RESEAU_AS_par_ZS" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    count(n4."ID_Niveau_4") AS "Nb_AS",
    sum(
        CASE
            WHEN ((g_reseau."AbrGenerique" IS NOT NULL) AND ((g_reseau."AbrGenerique")::text <> 'Sans reseau'::text)) THEN 1
            ELSE 0
        END) AS "Nb_AS_Avec_Reseau",
    round(((100.0 * (sum(
        CASE
            WHEN ((g_reseau."AbrGenerique" IS NOT NULL) AND ((g_reseau."AbrGenerique")::text <> 'Sans reseau'::text)) THEN 1
            ELSE 0
        END))::numeric) / (NULLIF(count(n4."ID_Niveau_4"), 0))::numeric), 1) AS "Pct_AS_Avec_Reseau"
   FROM (((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3";

--
-- Name: VIEW "V_RESEAU_AS_par_ZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_RESEAU_AS_par_ZS" IS 'Vue d''indicateurs connectivite : nombre et pourcentage d''Aires de Sante avec reseau par Zone de Sante.';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."Nb_AS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."Nb_AS" IS 'Nombre d’aires de santé rattachées à la zone. Expression projetée : count(n4."ID_Niveau_4") AS "Nb_AS".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."Nb_AS_Avec_Reseau"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."Nb_AS_Avec_Reseau" IS 'Nombre d’aires dont l’abréviation réseau est non NULL et différente exactement de Sans reseau. Expression projetée : sum( CASE WHEN g_reseau."AbrGenerique" IS NOT NULL AND g_reseau."AbrGenerique"::text <> ''Sans reseau''::text THEN 1 ELSE 0 END) AS "Nb_AS_Avec_Reseau".';

--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."Pct_AS_Avec_Reseau"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."Pct_AS_Avec_Reseau" IS 'Pourcentage des aires déclarées avec réseau sur le nombre d’aires ; arrondi à une décimale et NULL si dénominateur nul. Expression projetée : round(100.0 * sum( CASE WHEN g_reseau."AbrGenerique" IS NOT NULL AND g_reseau."AbrGenerique"::text <> ''Sans reseau''::text THEN 1 ELSE 0 END)::numeric / NULLIF(count(n4."ID_Niveau_4"), 0)::numeric, 1) AS "Pct_AS_Avec_Reseau".';

--
-- Name: V_Stats_N1_N2; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Stats_N1_N2" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_TypeNiveau_2_Fk",
    COALESCE(g_type2."AbrGenerique", ' '::character varying) AS "Type_Niveau_2",
    count(DISTINCT n2."ID_Niveau_2") AS "Nb_Niveau_2",
    sum(COALESCE(n2."PopulationNiveau_2", (0)::numeric)) AS "Pop_Niveau_2"
   FROM (((geolocalisation."T_Niveau_1" n1
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n1."ID_Niveau_1" = n2."ID_Niveau_1_FK")))
     LEFT JOIN referentiel."T_Generique" g_type2 ON ((n2."ID_TypeNiveau_2_Fk" = g_type2."ID_Generique")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_TypeNiveau_2_Fk", g_type2."AbrGenerique";

--
-- Name: VIEW "V_Stats_N1_N2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Stats_N1_N2" IS 'Vue d''indicateurs structurels : nombre d''unites de Niveau 2 et population de Niveau 2 par Niveau 1 et type.';

--
-- Name: COLUMN "V_Stats_N1_N2"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';

--
-- Name: COLUMN "V_Stats_N1_N2"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_Stats_N1_N2"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';

--
-- Name: COLUMN "V_Stats_N1_N2"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';

--
-- Name: COLUMN "V_Stats_N1_N2"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n2."ID_TypeNiveau_2_Fk".';

--
-- Name: COLUMN "V_Stats_N1_N2"."Type_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."Type_Niveau_2" IS 'Abréviation du type d’unité de niveau 2 dans le référentiel. Expression projetée : COALESCE(g_type2."AbrGenerique", '' ''::character varying) AS "Type_Niveau_2".';

--
-- Name: COLUMN "V_Stats_N1_N2"."Nb_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."Nb_Niveau_2" IS 'Nombre d’unités distinctes de niveau 2 pour le niveau 1 et le type considérés. Expression projetée : count(DISTINCT n2."ID_Niveau_2") AS "Nb_Niveau_2".';

--
-- Name: COLUMN "V_Stats_N1_N2"."Pop_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."Pop_Niveau_2" IS 'Somme des populations déclarées des unités de niveau 2 du groupe. Expression projetée : sum(COALESCE(n2."PopulationNiveau_2", 0::numeric)) AS "Pop_Niveau_2".';

--
-- Name: V_Stats_N3_Structures; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Stats_N3_Structures" AS
 WITH structures AS (
         SELECT COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk") AS region,
            n4."ID_Niveau_4",
            n4."ID_TypeNiveau_4_Fk",
            n5."ID_Niveau_5",
            n5."ID_TypeNiveau_5_Fk"
           FROM (geolocalisation."T_Niveau_4" n4
             LEFT JOIN geolocalisation."T_Niveau_5" n5 ON ((n5."ID_Niveau_4_Fk" = n4."ID_Niveau_4")))
        UNION ALL
         SELECT n5."ID_Niveau_3_Fk",
            NULL::integer AS int4,
            NULL::integer AS int4,
            n5."ID_Niveau_5",
            n5."ID_TypeNiveau_5_Fk"
           FROM geolocalisation."T_Niveau_5" n5
          WHERE ((n5."ID_Niveau_4_Fk" IS NULL) AND (n5."ID_Niveau_3_Fk" IS NOT NULL))
        )
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    s."ID_TypeNiveau_4_Fk",
    COALESCE(g4."AbrGenerique", ' '::character varying) AS "Type_Niveau_4",
    s."ID_TypeNiveau_5_Fk",
    COALESCE(g5."AbrGenerique", ' '::character varying) AS "Type_Niveau_5",
    count(DISTINCT s."ID_Niveau_4") AS "Nb_Aires_Sante",
    count(DISTINCT s."ID_Niveau_5") AS "Nb_Structures_Sante"
   FROM ((((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n2."ID_Niveau_2" = n3."ID_Niveau_2_FK")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n1."ID_Niveau_1" = n2."ID_Niveau_1_FK")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n0."ID_Niveau_0" = n1."ID_Niveau_0_Fk")))
     LEFT JOIN structures s ON ((s.region = n3."ID_Niveau_3")))
     LEFT JOIN referentiel."T_Generique" g4 ON ((g4."ID_Generique" = s."ID_TypeNiveau_4_Fk")))
     LEFT JOIN referentiel."T_Generique" g5 ON ((g5."ID_Generique" = s."ID_TypeNiveau_5_Fk")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3", s."ID_TypeNiveau_4_Fk", g4."AbrGenerique", s."ID_TypeNiveau_5_Fk", g5."AbrGenerique";

--
-- Name: VIEW "V_Stats_N3_Structures"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Stats_N3_Structures" IS 'Effectifs distincts par niveau 3 et paire de types niveau 4/niveau 5. Inclut les sites directement rattachés au niveau 3, sans leur inventer une aire de santé. Le nombre d’aires n’est pas additif entre groupes de types de sites.';

--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_TypeNiveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_TypeNiveau_4_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n4."ID_TypeNiveau_4_Fk".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."Type_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Type_Niveau_4" IS 'Abréviation du type d’unité de niveau 4 dans le référentiel. Expression projetée : COALESCE(g_type4."AbrGenerique", '' ''::character varying) AS "Type_Niveau_4".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_TypeNiveau_5_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n5."ID_TypeNiveau_5_Fk".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."Type_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Type_Niveau_5" IS 'Abréviation du type d’unité de niveau 5 dans le référentiel. Expression projetée : COALESCE(g_type5."AbrGenerique", '' ''::character varying) AS "Type_Niveau_5".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."Nb_Aires_Sante"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Nb_Aires_Sante" IS 'Nombre d’aires de santé distinctes dans le groupe zone/types de structure. Expression projetée : count(DISTINCT n4."ID_Niveau_4") AS "Nb_Aires_Sante".';

--
-- Name: COLUMN "V_Stats_N3_Structures"."Nb_Structures_Sante"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Nb_Structures_Sante" IS 'Nombre de sites distincts du groupe, par rattachement direct au niveau 3 ou via une aire ; aucun site direct n’est omis.';

--
-- Name: V_ZS_sans_AS; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_ZS_sans_AS" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3"
   FROM ((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3"
 HAVING (count(n4."ID_Niveau_4") = 0);

--
-- Name: VIEW "V_ZS_sans_AS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_ZS_sans_AS" IS 'Vue de controle qualite : Zones de Sante (Niveau 3) sans Aire de Sante (Niveau 4).';

--
-- Name: COLUMN "V_ZS_sans_AS"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';

--
-- Name: COLUMN "V_ZS_sans_AS"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';

--
-- Name: COLUMN "V_ZS_sans_AS"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';

--
-- Name: COLUMN "V_ZS_sans_AS"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';

--
-- Name: COLUMN "V_ZS_sans_AS"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';

--
-- Name: COLUMN "V_ZS_sans_AS"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';

--
-- Name: COLUMN "V_ZS_sans_AS"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';

--
-- Name: COLUMN "V_ZS_sans_AS"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';
