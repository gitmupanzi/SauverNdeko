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
    "geometryNiveau_0",
    "uidSNIS",
    ( SELECT count(*) AS count
           FROM geolocalisation."T_Niveau_1" child
          WHERE (child."ID_Niveau_0_Fk" = n0."ID_Niveau_0")) AS "Nb_Niveau_1"
   FROM geolocalisation."T_Niveau_0" n0;

--
-- Name: VIEW "V_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_0" IS 'Référentiel territorial partagé du niveau 0. Conserve les colonnes historiques et les rattachements absents ; expose les identifiants et libellés actuels ainsi que les compteurs exacts des enfants consultables, sans multiplication par les jointures ni exclusion implicite de visibilité.';

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
 SELECT q."ID_Niveau_0_Fk",
    q."NomNiveau_0",
    q."ID_Niveau_1_Old_Fk",
    q."NomNiveau_1_Old",
    q."ID_Niveau_1",
    q."NomNiveau_1",
    q."Alt1_Niveau_1",
    q."Alt2_Niveau_1",
    q."AbreNiveau_1",
    q."CodeSNIS",
    q."CodeNiveau_1",
    q."PopulationNiveau_1",
    q."LatitudeNiveau_1",
    q."LongitudeNiveau_1",
    q."surfaceNiveau_1",
    q."geometryNiveau_1",
    q."EtenduNiveau_1",
    q."timezoneNiveau_1",
    q."wikidataNiveau_1",
    q."FusionNiveau_1",
    q."VisibleNiveau_1",
    q."VisibleNiveau_5",
    q."ObsNiveau_1",
    q.prov_uid,
    q."uidSNIS",
    q."Nb_Niveau_2",
    q."AdresseTerritoire",
    q."TelephoneTerritoire",
    q."TelephoneSecondaireTerritoire",
    q."EmailTerritoire",
    q."SiteWebTerritoire",
    q."InformationsAccueilTerritoire",
    q."CoordonneesModifieLe",
    COALESCE(c."PublierCoordonneesAnnuaire", false) AS "PublierCoordonneesAnnuaire",
    c."HorairesOuvertureTerritoire"
   FROM (( SELECT q_1."ID_Niveau_0_Fk",
            q_1."NomNiveau_0",
            q_1."ID_Niveau_1_Old_Fk",
            q_1."NomNiveau_1_Old",
            q_1."ID_Niveau_1",
            q_1."NomNiveau_1",
            q_1."Alt1_Niveau_1",
            q_1."Alt2_Niveau_1",
            q_1."AbreNiveau_1",
            q_1."CodeSNIS",
            q_1."CodeNiveau_1",
            q_1."PopulationNiveau_1",
            q_1."LatitudeNiveau_1",
            q_1."LongitudeNiveau_1",
            q_1."surfaceNiveau_1",
            q_1."geometryNiveau_1",
            q_1."EtenduNiveau_1",
            q_1."timezoneNiveau_1",
            q_1."wikidataNiveau_1",
            q_1."FusionNiveau_1",
            q_1."VisibleNiveau_1",
            q_1."VisibleNiveau_5",
            q_1."ObsNiveau_1",
            q_1.prov_uid,
            q_1."uidSNIS",
            q_1."Nb_Niveau_2",
            c_1."AdresseTerritoire",
            c_1."TelephoneTerritoire",
            c_1."TelephoneSecondaireTerritoire",
            c_1."EmailTerritoire",
            c_1."SiteWebTerritoire",
            c_1."InformationsAccueilTerritoire",
            c_1."ModifieLe" AS "CoordonneesModifieLe"
           FROM (( SELECT n1a."ID_Niveau_0_Fk",
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
                    n1a."ObsNiveau_1",
                    n1a.prov_uid,
                    n1a."uidSNIS",
                    ( SELECT count(*) AS count
                           FROM geolocalisation."T_Niveau_2" child
                          WHERE (child."ID_Niveau_1_FK" = n1a."ID_Niveau_1")) AS "Nb_Niveau_2"
                   FROM ((geolocalisation."T_Niveau_1" n1a
                     LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON ((n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old")))
                     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))) q_1
             LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c_1 ON ((c_1."ID_Niveau_1Fk" = q_1."ID_Niveau_1")))) q
     LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON ((c."ID_Niveau_1Fk" = q."ID_Niveau_1")));

--
-- Name: VIEW "V_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_1" IS 'Référentiel territorial partagé du niveau 1. Colonnes, calculs, compteurs et rattachements historiques conservés ; coordonnées professionnelles facultatives ajoutées par une jointure unique. Aucun territoire exclu en l’absence de coordonnées, aucune entreprise ou affiliation déduite. Les liens et informations d’accueil sont déclaratifs.';

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
 SELECT q."NomNiveau_0",
    q."NomNiveau_1_Old",
    q."ID_Niveau_1_FK",
    q."NomNiveau_1",
    q."ID_Niveau_2",
    q."ID_TypeNiveau_2_Fk",
    q."Type_Niveau_2",
    q."NomNiveau_2",
    q."Alt1_NomNiveau_2",
    q."AbreNiveau_2",
    q."CodeNiveau_2",
    q."PopulationNiveau_2",
    q."LatitudeNiveau_2",
    q."LongitudeNiveau_2",
    q."AltitudeNiveau_2",
    q."geometryNiveau_2",
    q."surfaceNiveau_2",
    q."EtenduNiveau_2",
    q."ObsNiveau_2",
    q."ID_StatutNiveau_2",
    q."Statut_Niveau_2",
    q."ID_StatusDeploiFk",
    q."Statut_Deploiement",
    q."KmDPSANT",
    q."ID_VoieAccesDPSANTFk",
    q."Voie_Acces_DPS",
    q."SelectNiveau_2",
    q."ID_Niveau_0",
    q."ID_Niveau_1",
    q."FusionNiveau_1",
    q."VisibleNiveau_1",
    q."VisibleNiveau_5",
    q.iso,
    q."uidSNIS",
    q."Nb_Niveau_3",
    q."AdresseTerritoire",
    q."TelephoneTerritoire",
    q."TelephoneSecondaireTerritoire",
    q."EmailTerritoire",
    q."SiteWebTerritoire",
    q."InformationsAccueilTerritoire",
    q."CoordonneesModifieLe",
    COALESCE(c."PublierCoordonneesAnnuaire", false) AS "PublierCoordonneesAnnuaire",
    c."HorairesOuvertureTerritoire"
   FROM (( SELECT q_1."NomNiveau_0",
            q_1."NomNiveau_1_Old",
            q_1."ID_Niveau_1_FK",
            q_1."NomNiveau_1",
            q_1."ID_Niveau_2",
            q_1."ID_TypeNiveau_2_Fk",
            q_1."Type_Niveau_2",
            q_1."NomNiveau_2",
            q_1."Alt1_NomNiveau_2",
            q_1."AbreNiveau_2",
            q_1."CodeNiveau_2",
            q_1."PopulationNiveau_2",
            q_1."LatitudeNiveau_2",
            q_1."LongitudeNiveau_2",
            q_1."AltitudeNiveau_2",
            q_1."geometryNiveau_2",
            q_1."surfaceNiveau_2",
            q_1."EtenduNiveau_2",
            q_1."ObsNiveau_2",
            q_1."ID_StatutNiveau_2",
            q_1."Statut_Niveau_2",
            q_1."ID_StatusDeploiFk",
            q_1."Statut_Deploiement",
            q_1."KmDPSANT",
            q_1."ID_VoieAccesDPSANTFk",
            q_1."Voie_Acces_DPS",
            q_1."SelectNiveau_2",
            q_1."ID_Niveau_0",
            q_1."ID_Niveau_1",
            q_1."FusionNiveau_1",
            q_1."VisibleNiveau_1",
            q_1."VisibleNiveau_5",
            q_1.iso,
            q_1."uidSNIS",
            q_1."Nb_Niveau_3",
            c_1."AdresseTerritoire",
            c_1."TelephoneTerritoire",
            c_1."TelephoneSecondaireTerritoire",
            c_1."EmailTerritoire",
            c_1."SiteWebTerritoire",
            c_1."InformationsAccueilTerritoire",
            c_1."ModifieLe" AS "CoordonneesModifieLe"
           FROM (( SELECT n0."NomNiveau_0",
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
                    n2."SelectNiveau_2",
                    n1a."ID_Niveau_0_Fk" AS "ID_Niveau_0",
                    n1a."ID_Niveau_1",
                    n1a."FusionNiveau_1",
                    n1a."VisibleNiveau_1",
                    n1a."VisibleNiveau_5",
                    n2.iso,
                    n2."uidSNIS",
                    ( SELECT count(*) AS count
                           FROM geolocalisation."T_Niveau_3" child
                          WHERE (child."ID_Niveau_2_FK" = n2."ID_Niveau_2")) AS "Nb_Niveau_3"
                   FROM (((((((geolocalisation."T_Niveau_2" n2
                     LEFT JOIN geolocalisation."T_Niveau_1" n1a ON ((n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1")))
                     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
                     LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON ((n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old")))
                     LEFT JOIN referentiel."T_Generique" g_type ON ((n2."ID_TypeNiveau_2_Fk" = g_type."ID_Generique")))
                     LEFT JOIN referentiel."T_Generique" g_statut ON ((n2."ID_StatutNiveau_2" = g_statut."ID_Generique")))
                     LEFT JOIN referentiel."T_Generique" g_deploi ON ((n2."ID_StatusDeploiFk" = g_deploi."ID_Generique")))
                     LEFT JOIN referentiel."T_Generique" g_voie ON ((n2."ID_VoieAccesDPSANTFk" = g_voie."ID_Generique")))) q_1
             LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c_1 ON ((c_1."ID_Niveau_2Fk" = q_1."ID_Niveau_2")))) q
     LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON ((c."ID_Niveau_2Fk" = q."ID_Niveau_2")));

--
-- Name: VIEW "V_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_2" IS 'Référentiel territorial partagé du niveau 2. Colonnes, calculs, compteurs et rattachements historiques conservés ; coordonnées professionnelles facultatives ajoutées par une jointure unique. Aucun territoire exclu en l’absence de coordonnées, aucune entreprise ou affiliation déduite. Les liens et informations d’accueil sont déclaratifs.';

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
 SELECT q."ID_TypeNiveau_2_Fk",
    q."Type_Niveau_3",
    q."ID_Niveau_3",
    q."NomNiveau_3",
    q."Alt_Niveau_3",
    q."AbreNiveau_3",
    q."CodeNiveau_3",
    q."LatitudeNiveau_3",
    q."PopulationNiveau_3",
    q."LongitudeNiveau_3",
    q."AltitudeNiveau_3",
    q."EtenduNiveau_3",
    q."surfaceNiveau_3",
    q."geometryNiveau_3",
    q."ObsNiveau_3",
    q."ID_StatutNiveau_3_Fk",
    q."Statut_Niveau_3",
    q."ID_StatutDeploieFk",
    q."Statut_Deploiement",
    q."KmAntenneBCZS",
    q."ID_VoieAccesANTBCZFk",
    q."Voie_ANTBCZ",
    q."KmDPSBCZS",
    q."ID_VoieAccesDPSBCZFk",
    q."Voie_DPSBCZS",
    q."SelectNiveau_3",
    q."ID_Niveau_2_FK",
    q."ID_Niveau_0",
    q."NomNiveau_0",
    q."ID_Niveau_1",
    q."NomNiveau_1",
    q."ID_Niveau_2",
    q."NomNiveau_2",
    q."FusionNiveau_1",
    q."VisibleNiveau_1",
    q."VisibleNiveau_5",
    q.iso,
    q."uidSNIS",
    q."Nb_Niveau_4",
    q."Nb_Niveau_5",
    q."AdresseTerritoire",
    q."TelephoneTerritoire",
    q."TelephoneSecondaireTerritoire",
    q."EmailTerritoire",
    q."SiteWebTerritoire",
    q."InformationsAccueilTerritoire",
    q."CoordonneesModifieLe",
    COALESCE(c."PublierCoordonneesAnnuaire", false) AS "PublierCoordonneesAnnuaire",
    c."HorairesOuvertureTerritoire"
   FROM (( SELECT q_1."ID_TypeNiveau_2_Fk",
            q_1."Type_Niveau_3",
            q_1."ID_Niveau_3",
            q_1."NomNiveau_3",
            q_1."Alt_Niveau_3",
            q_1."AbreNiveau_3",
            q_1."CodeNiveau_3",
            q_1."LatitudeNiveau_3",
            q_1."PopulationNiveau_3",
            q_1."LongitudeNiveau_3",
            q_1."AltitudeNiveau_3",
            q_1."EtenduNiveau_3",
            q_1."surfaceNiveau_3",
            q_1."geometryNiveau_3",
            q_1."ObsNiveau_3",
            q_1."ID_StatutNiveau_3_Fk",
            q_1."Statut_Niveau_3",
            q_1."ID_StatutDeploieFk",
            q_1."Statut_Deploiement",
            q_1."KmAntenneBCZS",
            q_1."ID_VoieAccesANTBCZFk",
            q_1."Voie_ANTBCZ",
            q_1."KmDPSBCZS",
            q_1."ID_VoieAccesDPSBCZFk",
            q_1."Voie_DPSBCZS",
            q_1."SelectNiveau_3",
            q_1."ID_Niveau_2_FK",
            q_1."ID_Niveau_0",
            q_1."NomNiveau_0",
            q_1."ID_Niveau_1",
            q_1."NomNiveau_1",
            q_1."ID_Niveau_2",
            q_1."NomNiveau_2",
            q_1."FusionNiveau_1",
            q_1."VisibleNiveau_1",
            q_1."VisibleNiveau_5",
            q_1.iso,
            q_1."uidSNIS",
            q_1."Nb_Niveau_4",
            q_1."Nb_Niveau_5",
            c_1."AdresseTerritoire",
            c_1."TelephoneTerritoire",
            c_1."TelephoneSecondaireTerritoire",
            c_1."EmailTerritoire",
            c_1."SiteWebTerritoire",
            c_1."InformationsAccueilTerritoire",
            c_1."ModifieLe" AS "CoordonneesModifieLe"
           FROM (( SELECT n3."ID_TypeNiveau_2_Fk",
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
                    n3."ID_Niveau_2_FK",
                    n0."ID_Niveau_0",
                    n0."NomNiveau_0",
                    n1a."ID_Niveau_1",
                    n1a."NomNiveau_1",
                    n2."ID_Niveau_2",
                    n2."NomNiveau_2",
                    n1a."FusionNiveau_1",
                    n1a."VisibleNiveau_1",
                    n1a."VisibleNiveau_5",
                    n3.iso,
                    n3."uidSNIS",
                    ( SELECT count(*) AS count
                           FROM geolocalisation."T_Niveau_4" child
                          WHERE (child."ID_Niveau_3_Fk" = n3."ID_Niveau_3")) AS "Nb_Niveau_4",
                    (( SELECT count(*) AS count
                           FROM geolocalisation."T_Niveau_5" child
                          WHERE (child."ID_Niveau_3_Fk" = n3."ID_Niveau_3")) + ( SELECT count(*) AS count
                           FROM (geolocalisation."T_Niveau_4" area
                             JOIN geolocalisation."T_Niveau_5" child ON ((child."ID_Niveau_4_Fk" = area."ID_Niveau_4")))
                          WHERE ((child."ID_Niveau_3_Fk" IS NULL) AND (area."ID_Niveau_3_Fk" = n3."ID_Niveau_3")))) AS "Nb_Niveau_5"
                   FROM ((((((((geolocalisation."T_Niveau_3" n3
                     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
                     LEFT JOIN geolocalisation."T_Niveau_1" n1a ON ((n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1")))
                     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
                     LEFT JOIN referentiel."T_Generique" g_type ON ((n3."ID_TypeNiveau_2_Fk" = g_type."ID_Generique")))
                     LEFT JOIN referentiel."T_Generique" g_statut ON ((n3."ID_StatutNiveau_3_Fk" = g_statut."ID_Generique")))
                     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n3."ID_StatutDeploieFk" = g_deploiement."ID_Generique")))
                     LEFT JOIN referentiel."T_Generique" g_voie1 ON ((n3."ID_VoieAccesANTBCZFk" = g_voie1."ID_Generique")))
                     LEFT JOIN referentiel."T_Generique" g_voie2 ON ((n3."ID_VoieAccesDPSBCZFk" = g_voie2."ID_Generique")))) q_1
             LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c_1 ON ((c_1."ID_Niveau_3Fk" = q_1."ID_Niveau_3")))) q
     LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON ((c."ID_Niveau_3Fk" = q."ID_Niveau_3")));

--
-- Name: VIEW "V_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_3" IS 'Référentiel territorial partagé du niveau 3. Colonnes, calculs, compteurs et rattachements historiques conservés ; coordonnées professionnelles facultatives ajoutées par une jointure unique. Aucun territoire exclu en l’absence de coordonnées, aucune entreprise ou affiliation déduite. Les liens et informations d’accueil sont déclaratifs.';

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
 SELECT q."ID_Niveau_0",
    q."NomNiveau_0",
    q."ID_Niveau_1",
    q."NomNiveau_1",
    q."ID_Niveau_2",
    q."NomNiveau_2",
    q."ID_Niveau_3",
    q."NomNiveau_3",
    q."ID_TypeNiveau_4_Fk",
    q."Type_Niveau_4",
    q."AbreNiveau_4",
    q."SITE",
    q."CodeNiveau_4",
    q."PopulationNiveau_4",
    q."LatitudeNiveau_4",
    q."LongitudeNiveau_4",
    q."AltitudeNiveau_4",
    q."geometryNiveau_4",
    q."RESEAU",
    q."VOIE_AS_ZS",
    q."STATUT_AS",
    q."STATUT_DEPLOI",
    q."KmAntenneBCZS",
    q."KmDPSBCZS",
    q."ObsNiveau_4",
    q."SelectNiveau_4",
    q."ID_Niveau_4",
    q."ID_Niveau_3_Fk",
    q."NomNiveau_4",
    q."KmZoneSanteAS",
    q."surfaceNiveau_4",
    q."ID_DispoReseauNiveau_4",
    q."ID_VoieAccesZsASFk",
    q."ID_StatutNiveau_4",
    q."ID_StatutDeploiementFk",
    q."FusionNiveau_1",
    q."VisibleNiveau_1",
    q."VisibleNiveau_5",
    q.iso,
    q."uidSNIS",
    q."Nb_Niveau_5",
    q."AvecReseau",
    q."AdresseTerritoire",
    q."TelephoneTerritoire",
    q."TelephoneSecondaireTerritoire",
    q."EmailTerritoire",
    q."SiteWebTerritoire",
    q."InformationsAccueilTerritoire",
    q."CoordonneesModifieLe",
    COALESCE(c."PublierCoordonneesAnnuaire", false) AS "PublierCoordonneesAnnuaire",
    c."HorairesOuvertureTerritoire"
   FROM (( SELECT q_1."ID_Niveau_0",
            q_1."NomNiveau_0",
            q_1."ID_Niveau_1",
            q_1."NomNiveau_1",
            q_1."ID_Niveau_2",
            q_1."NomNiveau_2",
            q_1."ID_Niveau_3",
            q_1."NomNiveau_3",
            q_1."ID_TypeNiveau_4_Fk",
            q_1."Type_Niveau_4",
            q_1."AbreNiveau_4",
            q_1."SITE",
            q_1."CodeNiveau_4",
            q_1."PopulationNiveau_4",
            q_1."LatitudeNiveau_4",
            q_1."LongitudeNiveau_4",
            q_1."AltitudeNiveau_4",
            q_1."geometryNiveau_4",
            q_1."RESEAU",
            q_1."VOIE_AS_ZS",
            q_1."STATUT_AS",
            q_1."STATUT_DEPLOI",
            q_1."KmAntenneBCZS",
            q_1."KmDPSBCZS",
            q_1."ObsNiveau_4",
            q_1."SelectNiveau_4",
            q_1."ID_Niveau_4",
            q_1."ID_Niveau_3_Fk",
            q_1."NomNiveau_4",
            q_1."KmZoneSanteAS",
            q_1."surfaceNiveau_4",
            q_1."ID_DispoReseauNiveau_4",
            q_1."ID_VoieAccesZsASFk",
            q_1."ID_StatutNiveau_4",
            q_1."ID_StatutDeploiementFk",
            q_1."FusionNiveau_1",
            q_1."VisibleNiveau_1",
            q_1."VisibleNiveau_5",
            q_1.iso,
            q_1."uidSNIS",
            q_1."Nb_Niveau_5",
            q_1."AvecReseau",
            c_1."AdresseTerritoire",
            c_1."TelephoneTerritoire",
            c_1."TelephoneSecondaireTerritoire",
            c_1."EmailTerritoire",
            c_1."SiteWebTerritoire",
            c_1."InformationsAccueilTerritoire",
            c_1."ModifieLe" AS "CoordonneesModifieLe"
           FROM (( SELECT n0."ID_Niveau_0",
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
                    n4."ID_StatutDeploiementFk",
                    n1."FusionNiveau_1",
                    n1."VisibleNiveau_1",
                    n1."VisibleNiveau_5",
                    n4.iso,
                    n4."uidSNIS",
                    ( SELECT count(*) AS count
                           FROM geolocalisation."T_Niveau_5" child
                          WHERE (child."ID_Niveau_4_Fk" = n4."ID_Niveau_4")) AS "Nb_Niveau_5",
                    ((g_reseau."AbrGenerique" IS NOT NULL) AND ((g_reseau."AbrGenerique")::text <> 'Sans reseau'::text)) AS "AvecReseau"
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
                  ORDER BY n0."NomNiveau_0", n1."NomNiveau_1", n2."NomNiveau_2", n3."NomNiveau_3", n4."NomNiveau_4") q_1
             LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c_1 ON ((c_1."ID_Niveau_4Fk" = q_1."ID_Niveau_4")))) q
     LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON ((c."ID_Niveau_4Fk" = q."ID_Niveau_4")));

--
-- Name: VIEW "V_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_4" IS 'Référentiel territorial partagé du niveau 4. Colonnes, calculs, compteurs et rattachements historiques conservés ; coordonnées professionnelles facultatives ajoutées par une jointure unique. Aucun territoire exclu en l’absence de coordonnées, aucune entreprise ou affiliation déduite. Les liens et informations d’accueil sont déclaratifs.';

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
 SELECT q."ID_Niveau_0",
    q."NomNiveau_0",
    q."ID_Niveau_1",
    q."NomNiveau_1",
    q."ID_Niveau_2",
    q."NomNiveau_2",
    q."ID_Niveau_3",
    q."NomNiveau_3",
    q."ID_TypeNiveau_5_Fk",
    q."Type_Niveau_5",
    q."SITE",
    q."AbreNiveau_5",
    q."CodeNiveau_5",
    q."PopulationNiveau_5",
    q."LongitudeNiveau_5",
    q."LatitudeNiveau_5",
    q."AltitudeNiveau_5",
    q."geometryNiveau_5",
    q."RESEAU",
    q."VOIE_AS_Site",
    q."STATUT_Site",
    q."STATUT_DEPLOI",
    q."KmAntenneBCZS",
    q."KmDPSBCZS",
    q."ID_Niveau_4",
    q."ID_Niveau_5",
    q."ID_Niveau_4_Fk",
    q."ID_Niveau_3_Fk",
    q."NomNiveau_5",
    q."KmZoneSanteNiveau_5",
    q."surfaceNiveau_5",
    q."ID_DispoReseauNiveau_5",
    q."ID_VoieAccesZsSiteFk",
    q."ID_StatutNiveau_5",
    q."ID_StatutDeploiementFk",
    q."ID_TypeToitFk",
    q."ObsNiveau_5",
    q."SelectNiveau_5",
    q."NomNiveau_4",
    q."Type_Toit",
    q."FusionNiveau_1",
    q."VisibleNiveau_1",
    q."VisibleNiveau_5",
    q.iso,
    q."uidSNIS",
    q."ID_TypeNiveau_4_Fk",
    q."AdresseTerritoire",
    q."TelephoneTerritoire",
    q."TelephoneSecondaireTerritoire",
    q."EmailTerritoire",
    q."SiteWebTerritoire",
    q."InformationsAccueilTerritoire",
    q."CoordonneesModifieLe",
    COALESCE(c."PublierCoordonneesAnnuaire", false) AS "PublierCoordonneesAnnuaire",
    c."HorairesOuvertureTerritoire"
   FROM (( SELECT q_1."ID_Niveau_0",
            q_1."NomNiveau_0",
            q_1."ID_Niveau_1",
            q_1."NomNiveau_1",
            q_1."ID_Niveau_2",
            q_1."NomNiveau_2",
            q_1."ID_Niveau_3",
            q_1."NomNiveau_3",
            q_1."ID_TypeNiveau_5_Fk",
            q_1."Type_Niveau_5",
            q_1."SITE",
            q_1."AbreNiveau_5",
            q_1."CodeNiveau_5",
            q_1."PopulationNiveau_5",
            q_1."LongitudeNiveau_5",
            q_1."LatitudeNiveau_5",
            q_1."AltitudeNiveau_5",
            q_1."geometryNiveau_5",
            q_1."RESEAU",
            q_1."VOIE_AS_Site",
            q_1."STATUT_Site",
            q_1."STATUT_DEPLOI",
            q_1."KmAntenneBCZS",
            q_1."KmDPSBCZS",
            q_1."ID_Niveau_4",
            q_1."ID_Niveau_5",
            q_1."ID_Niveau_4_Fk",
            q_1."ID_Niveau_3_Fk",
            q_1."NomNiveau_5",
            q_1."KmZoneSanteNiveau_5",
            q_1."surfaceNiveau_5",
            q_1."ID_DispoReseauNiveau_5",
            q_1."ID_VoieAccesZsSiteFk",
            q_1."ID_StatutNiveau_5",
            q_1."ID_StatutDeploiementFk",
            q_1."ID_TypeToitFk",
            q_1."ObsNiveau_5",
            q_1."SelectNiveau_5",
            q_1."NomNiveau_4",
            q_1."Type_Toit",
            q_1."FusionNiveau_1",
            q_1."VisibleNiveau_1",
            q_1."VisibleNiveau_5",
            q_1.iso,
            q_1."uidSNIS",
            q_1."ID_TypeNiveau_4_Fk",
            c_1."AdresseTerritoire",
            c_1."TelephoneTerritoire",
            c_1."TelephoneSecondaireTerritoire",
            c_1."EmailTerritoire",
            c_1."SiteWebTerritoire",
            c_1."InformationsAccueilTerritoire",
            c_1."ModifieLe" AS "CoordonneesModifieLe"
           FROM (( SELECT n0."ID_Niveau_0",
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
                    n5."SelectNiveau_5",
                    n4."NomNiveau_4",
                    ( SELECT roof."AbrGenerique"
                           FROM referentiel."T_Generique" roof
                          WHERE (roof."ID_Generique" = n5."ID_TypeToitFk")) AS "Type_Toit",
                    n1."FusionNiveau_1",
                    n1."VisibleNiveau_1",
                    n1."VisibleNiveau_5",
                    n5.iso,
                    n5."uidSNIS",
                    n4."ID_TypeNiveau_4_Fk"
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
                  ORDER BY n0."NomNiveau_0", n1."NomNiveau_1", n2."NomNiveau_2", n3."NomNiveau_3", n5."NomNiveau_5") q_1
             LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c_1 ON ((c_1."ID_Niveau_5Fk" = q_1."ID_Niveau_5")))) q
     LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON ((c."ID_Niveau_5Fk" = q."ID_Niveau_5")));

--
-- Name: VIEW "V_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_5" IS 'Référentiel territorial partagé du niveau 5. Colonnes, calculs, compteurs et rattachements historiques conservés ; coordonnées professionnelles facultatives ajoutées par une jointure unique. Aucun territoire exclu en l’absence de coordonnées, aucune entreprise ou affiliation déduite. Les liens et informations d’accueil sont déclaratifs.';

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

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."uidSNIS" IS 'Identifiant SNIS du pays ou territoire, conservé depuis la table source sans transformation.';

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."Nb_Niveau_1" IS 'Nombre exact de niveaux 1 rattachés à ce pays, sans exclusion implicite de fusion ou visibilité. Correspond au registre des provinces filtré sur ID_Niveau_0_Fk.';

COMMENT ON COLUMN geolocalisation."V_Niveau_1".prov_uid IS 'Identifiant provincial complémentaire, conservé depuis la table source.';

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."uidSNIS" IS 'Identifiant SNIS provincial, conservé depuis la table source.';

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."Nb_Niveau_2" IS 'Nombre exact de niveaux 2 rattachés à la province. Correspond au registre des antennes filtré sur ID_Niveau_1_FK.';

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_0" IS 'Identifiant du pays parent obtenu par la province, utilisable pour filtrer le découpage partagé.';

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_1" IS 'Identifiant de province parent ; alias de lecture compatible avec les analyses territoriales.';

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente ; NULL reste inconnu, aucune exclusion automatique.';

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."VisibleNiveau_1" IS 'Visibilité déclarée du niveau provincial parent, sans restriction implicite des compteurs.';

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."VisibleNiveau_5" IS 'Visibilité des sites déclarée par la province parente, conservée sans modifier ses sites.';

COMMENT ON COLUMN geolocalisation."V_Niveau_2".iso IS 'Code ISO ou identifiant géographique enregistré pour cette subdivision.';

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette subdivision.';

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Nb_Niveau_3" IS 'Nombre exact de zones de santé rattachées à cette subdivision. Correspond au registre des zones filtré sur ID_Niveau_2_FK.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_0" IS 'Identifiant du pays parent obtenu par les jointures de rattachement.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_0" IS 'Nom courant du pays parent, issu de la source unique géographique.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_1" IS 'Identifiant de la province parente de la zone.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_1" IS 'Nom courant de la province parente de la zone.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_2" IS 'Identifiant de la subdivision parente de la zone.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_2" IS 'Nom courant de la subdivision parente de la zone.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."FusionNiveau_1" IS 'Indicateur de fusion provincial, exposé pour les filtres sans exclusion implicite.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente ; aucun territoire n’est masqué par cette vue.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."VisibleNiveau_5" IS 'Visibilité déclarée des sites de la province parente, sans réécriture de données.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3".iso IS 'Code ISO ou identifiant géographique enregistré pour cette zone.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette zone.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Nb_Niveau_4" IS 'Nombre exact d’aires rattachées à cette zone. Correspond au registre des aires filtré sur ID_Niveau_3_Fk.';

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Nb_Niveau_5" IS 'Nombre exact de sites de cette zone : rattachement direct prioritaire, sinon zone de l’aire. Chaque site compte une fois. Correspond au registre des sites filtré sur ID_Niveau_3 effectif.';

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente, sans filtre implicite.';

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente, exposée sans altération.';

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."VisibleNiveau_5" IS 'Visibilité déclarée des sites au niveau provincial parent.';

COMMENT ON COLUMN geolocalisation."V_Niveau_4".iso IS 'Code ISO ou identifiant géographique enregistré pour cette aire.';

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette aire.';

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."Nb_Niveau_5" IS 'Nombre exact de sites directement rattachés à cette aire. Les sites rattachés seulement à une zone ne sont pas attribués arbitrairement à une aire.';

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AvecReseau" IS 'Indicateur exact du rapport Réseau des aires : abréviation réseau renseignée et différente de « Sans reseau ». Ne constitue pas une certification de connectivité.';

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_4" IS 'Nom courant de l’aire lorsque le site lui est réellement rattaché ; NULL si aucun rattachement à une aire.';

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."Type_Toit" IS 'Abréviation du type de toit selon la valeur générique enregistrée ; ne remplace pas sa clé étrangère.';

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente, sans exclusion implicite des sites.';

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente du site.';

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."VisibleNiveau_5" IS 'Visibilité déclarée des sites au niveau provincial parent.';

COMMENT ON COLUMN geolocalisation."V_Niveau_5".iso IS 'Code ISO ou identifiant géographique enregistré pour ce site.';

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."uidSNIS" IS 'Identifiant SNIS enregistré pour ce site.';

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_TypeNiveau_4_Fk" IS 'Type de l’aire réellement liée au site ; NULL lorsque le site n’a pas d’aire ou que son type est absent. Permet le détail exact des analyses par type d’aire.';
--
-- Name: COLUMN "V_Niveau_1".prov_uid; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1".prov_uid IS 'Identifiant provincial complémentaire, conservé depuis la table source.';

--
-- Name: COLUMN "V_Niveau_1"."uidSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."uidSNIS" IS 'Identifiant SNIS provincial, conservé depuis la table source.';

--
-- Name: COLUMN "V_Niveau_1"."Nb_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."Nb_Niveau_2" IS 'Nombre exact de niveaux 2 rattachés à la province. Correspond au registre des antennes filtré sur ID_Niveau_1_FK.';

--
-- Name: COLUMN "V_Niveau_1"."AdresseTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."AdresseTerritoire" IS 'Adresse professionnelle facultative explicitement déclarée pour ce territoire ; aucune localisation calculée.';

--
-- Name: COLUMN "V_Niveau_1"."TelephoneTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."TelephoneTerritoire" IS 'Téléphone professionnel principal déclaré du territoire, distinct des comptes utilisateurs.';

--
-- Name: COLUMN "V_Niveau_1"."TelephoneSecondaireTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."TelephoneSecondaireTerritoire" IS 'Téléphone professionnel secondaire facultatif déclaré pour le territoire.';

--
-- Name: COLUMN "V_Niveau_1"."EmailTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."EmailTerritoire" IS 'Adresse e-mail professionnelle facultative déclarée du territoire.';

--
-- Name: COLUMN "V_Niveau_1"."SiteWebTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."SiteWebTerritoire" IS 'Site web professionnel facultatif déclaré du territoire, sans agrément implicite.';

--
-- Name: COLUMN "V_Niveau_1"."InformationsAccueilTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."InformationsAccueilTerritoire" IS 'Informations d’accueil déclarées, affichées en texte simple sans garantie de permanence ou de certification.';

--
-- Name: COLUMN "V_Niveau_1"."CoordonneesModifieLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."CoordonneesModifieLe" IS 'Dernière écriture technique de la fiche de coordonnées ; NULL en son absence. Ne constitue pas une date de vérification métier.';

--
-- Name: COLUMN "V_Niveau_2"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_0" IS 'Identifiant du pays parent obtenu par la province, utilisable pour filtrer le découpage partagé.';

--
-- Name: COLUMN "V_Niveau_2"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_1" IS 'Identifiant de province parent ; alias de lecture compatible avec les analyses territoriales.';

--
-- Name: COLUMN "V_Niveau_2"."FusionNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente ; NULL reste inconnu, aucune exclusion automatique.';

--
-- Name: COLUMN "V_Niveau_2"."VisibleNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."VisibleNiveau_1" IS 'Visibilité déclarée du niveau provincial parent, sans restriction implicite des compteurs.';

--
-- Name: COLUMN "V_Niveau_2"."VisibleNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."VisibleNiveau_5" IS 'Visibilité des sites déclarée par la province parente, conservée sans modifier ses sites.';

--
-- Name: COLUMN "V_Niveau_2".iso; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2".iso IS 'Code ISO ou identifiant géographique enregistré pour cette subdivision.';

--
-- Name: COLUMN "V_Niveau_2"."uidSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette subdivision.';

--
-- Name: COLUMN "V_Niveau_2"."Nb_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Nb_Niveau_3" IS 'Nombre exact de zones de santé rattachées à cette subdivision. Correspond au registre des zones filtré sur ID_Niveau_2_FK.';

--
-- Name: COLUMN "V_Niveau_2"."AdresseTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."AdresseTerritoire" IS 'Adresse professionnelle facultative explicitement déclarée pour ce territoire ; aucune localisation calculée.';

--
-- Name: COLUMN "V_Niveau_2"."TelephoneTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."TelephoneTerritoire" IS 'Téléphone professionnel principal déclaré du territoire, distinct des comptes utilisateurs.';

--
-- Name: COLUMN "V_Niveau_2"."TelephoneSecondaireTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."TelephoneSecondaireTerritoire" IS 'Téléphone professionnel secondaire facultatif déclaré pour le territoire.';

--
-- Name: COLUMN "V_Niveau_2"."EmailTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."EmailTerritoire" IS 'Adresse e-mail professionnelle facultative déclarée du territoire.';

--
-- Name: COLUMN "V_Niveau_2"."SiteWebTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."SiteWebTerritoire" IS 'Site web professionnel facultatif déclaré du territoire, sans agrément implicite.';

--
-- Name: COLUMN "V_Niveau_2"."InformationsAccueilTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."InformationsAccueilTerritoire" IS 'Informations d’accueil déclarées, affichées en texte simple sans garantie de permanence ou de certification.';

--
-- Name: COLUMN "V_Niveau_2"."CoordonneesModifieLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."CoordonneesModifieLe" IS 'Dernière écriture technique de la fiche de coordonnées ; NULL en son absence. Ne constitue pas une date de vérification métier.';

--
-- Name: COLUMN "V_Niveau_3"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_0" IS 'Identifiant du pays parent obtenu par les jointures de rattachement.';

--
-- Name: COLUMN "V_Niveau_3"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_0" IS 'Nom courant du pays parent, issu de la source unique géographique.';

--
-- Name: COLUMN "V_Niveau_3"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_1" IS 'Identifiant de la province parente de la zone.';

--
-- Name: COLUMN "V_Niveau_3"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_1" IS 'Nom courant de la province parente de la zone.';

--
-- Name: COLUMN "V_Niveau_3"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_2" IS 'Identifiant de la subdivision parente de la zone.';

--
-- Name: COLUMN "V_Niveau_3"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_2" IS 'Nom courant de la subdivision parente de la zone.';

--
-- Name: COLUMN "V_Niveau_3"."FusionNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."FusionNiveau_1" IS 'Indicateur de fusion provincial, exposé pour les filtres sans exclusion implicite.';

--
-- Name: COLUMN "V_Niveau_3"."VisibleNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente ; aucun territoire n’est masqué par cette vue.';

--
-- Name: COLUMN "V_Niveau_3"."VisibleNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."VisibleNiveau_5" IS 'Visibilité déclarée des sites de la province parente, sans réécriture de données.';

--
-- Name: COLUMN "V_Niveau_3".iso; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3".iso IS 'Code ISO ou identifiant géographique enregistré pour cette zone.';

--
-- Name: COLUMN "V_Niveau_3"."uidSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette zone.';

--
-- Name: COLUMN "V_Niveau_3"."Nb_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Nb_Niveau_4" IS 'Nombre exact d’aires rattachées à cette zone. Correspond au registre des aires filtré sur ID_Niveau_3_Fk.';

--
-- Name: COLUMN "V_Niveau_3"."Nb_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Nb_Niveau_5" IS 'Nombre exact de sites de cette zone : rattachement direct prioritaire, sinon zone de l’aire. Chaque site compte une fois. Correspond au registre des sites filtré sur ID_Niveau_3 effectif.';

--
-- Name: COLUMN "V_Niveau_3"."AdresseTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."AdresseTerritoire" IS 'Adresse professionnelle facultative explicitement déclarée pour ce territoire ; aucune localisation calculée.';

--
-- Name: COLUMN "V_Niveau_3"."TelephoneTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."TelephoneTerritoire" IS 'Téléphone professionnel principal déclaré du territoire, distinct des comptes utilisateurs.';

--
-- Name: COLUMN "V_Niveau_3"."TelephoneSecondaireTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."TelephoneSecondaireTerritoire" IS 'Téléphone professionnel secondaire facultatif déclaré pour le territoire.';

--
-- Name: COLUMN "V_Niveau_3"."EmailTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."EmailTerritoire" IS 'Adresse e-mail professionnelle facultative déclarée du territoire.';

--
-- Name: COLUMN "V_Niveau_3"."SiteWebTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."SiteWebTerritoire" IS 'Site web professionnel facultatif déclaré du territoire, sans agrément implicite.';

--
-- Name: COLUMN "V_Niveau_3"."InformationsAccueilTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."InformationsAccueilTerritoire" IS 'Informations d’accueil déclarées, affichées en texte simple sans garantie de permanence ou de certification.';

--
-- Name: COLUMN "V_Niveau_3"."CoordonneesModifieLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."CoordonneesModifieLe" IS 'Dernière écriture technique de la fiche de coordonnées ; NULL en son absence. Ne constitue pas une date de vérification métier.';

--
-- Name: COLUMN "V_Niveau_4"."FusionNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente, sans filtre implicite.';

--
-- Name: COLUMN "V_Niveau_4"."VisibleNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente, exposée sans altération.';

--
-- Name: COLUMN "V_Niveau_4"."VisibleNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."VisibleNiveau_5" IS 'Visibilité déclarée des sites au niveau provincial parent.';

--
-- Name: COLUMN "V_Niveau_4".iso; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4".iso IS 'Code ISO ou identifiant géographique enregistré pour cette aire.';

--
-- Name: COLUMN "V_Niveau_4"."uidSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette aire.';

--
-- Name: COLUMN "V_Niveau_4"."Nb_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."Nb_Niveau_5" IS 'Nombre exact de sites directement rattachés à cette aire. Les sites rattachés seulement à une zone ne sont pas attribués arbitrairement à une aire.';

--
-- Name: COLUMN "V_Niveau_4"."AvecReseau"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AvecReseau" IS 'Indicateur exact du rapport Réseau des aires : abréviation réseau renseignée et différente de « Sans reseau ». Ne constitue pas une certification de connectivité.';

--
-- Name: COLUMN "V_Niveau_4"."AdresseTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AdresseTerritoire" IS 'Adresse professionnelle facultative explicitement déclarée pour ce territoire ; aucune localisation calculée.';

--
-- Name: COLUMN "V_Niveau_4"."TelephoneTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."TelephoneTerritoire" IS 'Téléphone professionnel principal déclaré du territoire, distinct des comptes utilisateurs.';

--
-- Name: COLUMN "V_Niveau_4"."TelephoneSecondaireTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."TelephoneSecondaireTerritoire" IS 'Téléphone professionnel secondaire facultatif déclaré pour le territoire.';

--
-- Name: COLUMN "V_Niveau_4"."EmailTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."EmailTerritoire" IS 'Adresse e-mail professionnelle facultative déclarée du territoire.';

--
-- Name: COLUMN "V_Niveau_4"."SiteWebTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."SiteWebTerritoire" IS 'Site web professionnel facultatif déclaré du territoire, sans agrément implicite.';

--
-- Name: COLUMN "V_Niveau_4"."InformationsAccueilTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."InformationsAccueilTerritoire" IS 'Informations d’accueil déclarées, affichées en texte simple sans garantie de permanence ou de certification.';

--
-- Name: COLUMN "V_Niveau_4"."CoordonneesModifieLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."CoordonneesModifieLe" IS 'Dernière écriture technique de la fiche de coordonnées ; NULL en son absence. Ne constitue pas une date de vérification métier.';

--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_4" IS 'Nom courant de l’aire lorsque le site lui est réellement rattaché ; NULL si aucun rattachement à une aire.';

--
-- Name: COLUMN "V_Niveau_5"."Type_Toit"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."Type_Toit" IS 'Abréviation du type de toit selon la valeur générique enregistrée ; ne remplace pas sa clé étrangère.';

--
-- Name: COLUMN "V_Niveau_5"."FusionNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente, sans exclusion implicite des sites.';

--
-- Name: COLUMN "V_Niveau_5"."VisibleNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente du site.';

--
-- Name: COLUMN "V_Niveau_5"."VisibleNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."VisibleNiveau_5" IS 'Visibilité déclarée des sites au niveau provincial parent.';

--
-- Name: COLUMN "V_Niveau_5".iso; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5".iso IS 'Code ISO ou identifiant géographique enregistré pour ce site.';

--
-- Name: COLUMN "V_Niveau_5"."uidSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."uidSNIS" IS 'Identifiant SNIS enregistré pour ce site.';

--
-- Name: COLUMN "V_Niveau_5"."ID_TypeNiveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_TypeNiveau_4_Fk" IS 'Type de l’aire réellement liée au site ; NULL lorsque le site n’a pas d’aire ou que son type est absent. Permet le détail exact des analyses par type d’aire.';

--
-- Name: COLUMN "V_Niveau_5"."AdresseTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."AdresseTerritoire" IS 'Adresse professionnelle facultative explicitement déclarée pour ce territoire ; aucune localisation calculée.';

--
-- Name: COLUMN "V_Niveau_5"."TelephoneTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."TelephoneTerritoire" IS 'Téléphone professionnel principal déclaré du territoire, distinct des comptes utilisateurs.';

--
-- Name: COLUMN "V_Niveau_5"."TelephoneSecondaireTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."TelephoneSecondaireTerritoire" IS 'Téléphone professionnel secondaire facultatif déclaré pour le territoire.';

--
-- Name: COLUMN "V_Niveau_5"."EmailTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."EmailTerritoire" IS 'Adresse e-mail professionnelle facultative déclarée du territoire.';

--
-- Name: COLUMN "V_Niveau_5"."SiteWebTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."SiteWebTerritoire" IS 'Site web professionnel facultatif déclaré du territoire, sans agrément implicite.';

--
-- Name: COLUMN "V_Niveau_5"."InformationsAccueilTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."InformationsAccueilTerritoire" IS 'Informations d’accueil déclarées, affichées en texte simple sans garantie de permanence ou de certification.';

--
-- Name: COLUMN "V_Niveau_5"."CoordonneesModifieLe"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."CoordonneesModifieLe" IS 'Dernière écriture technique de la fiche de coordonnées ; NULL en son absence. Ne constitue pas une date de vérification métier.';
--
-- Name: COLUMN "V_Niveau_1"."PublierCoordonneesAnnuaire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."PublierCoordonneesAnnuaire" IS 'Choix explicite de publication des coordonnées dans l’annuaire sanitaire ; false en l’absence de fiche. Lecture territoriale privée : ce champ ne masque pas les contacts dans ce registre administrateur.';

--
-- Name: COLUMN "V_Niveau_1"."HorairesOuvertureTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."HorairesOuvertureTerritoire" IS 'Horaires d’ouverture déclarés, facultatifs, conservés dans la fiche territoriale associée. Aucun héritage depuis les parents, aucun calcul d’ouverture actuelle.';

--
-- Name: COLUMN "V_Niveau_2"."PublierCoordonneesAnnuaire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."PublierCoordonneesAnnuaire" IS 'Choix explicite de publication des coordonnées dans l’annuaire sanitaire ; false en l’absence de fiche. Lecture territoriale privée : ce champ ne masque pas les contacts dans ce registre administrateur.';

--
-- Name: COLUMN "V_Niveau_2"."HorairesOuvertureTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."HorairesOuvertureTerritoire" IS 'Horaires d’ouverture déclarés, facultatifs, conservés dans la fiche territoriale associée. Aucun héritage depuis les parents, aucun calcul d’ouverture actuelle.';

--
-- Name: COLUMN "V_Niveau_3"."PublierCoordonneesAnnuaire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."PublierCoordonneesAnnuaire" IS 'Choix explicite de publication des coordonnées dans l’annuaire sanitaire ; false en l’absence de fiche. Lecture territoriale privée : ce champ ne masque pas les contacts dans ce registre administrateur.';

--
-- Name: COLUMN "V_Niveau_3"."HorairesOuvertureTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."HorairesOuvertureTerritoire" IS 'Horaires d’ouverture déclarés, facultatifs, conservés dans la fiche territoriale associée. Aucun héritage depuis les parents, aucun calcul d’ouverture actuelle.';

--
-- Name: COLUMN "V_Niveau_4"."PublierCoordonneesAnnuaire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."PublierCoordonneesAnnuaire" IS 'Choix explicite de publication des coordonnées dans l’annuaire sanitaire ; false en l’absence de fiche. Lecture territoriale privée : ce champ ne masque pas les contacts dans ce registre administrateur.';

--
-- Name: COLUMN "V_Niveau_4"."HorairesOuvertureTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."HorairesOuvertureTerritoire" IS 'Horaires d’ouverture déclarés, facultatifs, conservés dans la fiche territoriale associée. Aucun héritage depuis les parents, aucun calcul d’ouverture actuelle.';

--
-- Name: COLUMN "V_Niveau_5"."PublierCoordonneesAnnuaire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."PublierCoordonneesAnnuaire" IS 'Choix explicite de publication des coordonnées dans l’annuaire sanitaire ; false en l’absence de fiche. Lecture territoriale privée : ce champ ne masque pas les contacts dans ce registre administrateur.';

--
-- Name: COLUMN "V_Niveau_5"."HorairesOuvertureTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."HorairesOuvertureTerritoire" IS 'Horaires d’ouverture déclarés, facultatifs, conservés dans la fiche territoriale associée. Aucun héritage depuis les parents, aucun calcul d’ouverture actuelle.';

--
-- Name: V_StructureSanitairePublique; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_StructureSanitairePublique" AS
 SELECT ('n3:'::text || (v."ID_Niveau_3")::text) AS "StructureKey",
    3 AS "NiveauStructure",
    v."ID_Niveau_3" AS "ID_Structure",
    v."NomNiveau_3" AS "NomStructure",
    v."CodeNiveau_3" AS "CodeStructure",
    g."ID_Generique" AS "ID_TypeStructureFk",
    COALESCE(NULLIF(btrim((g."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (g."ID_Generique")::text)) AS "TypeStructure",
    v."ID_Niveau_1",
    v."NomNiveau_1",
    v."ID_Niveau_2",
    v."NomNiveau_2",
    v."ID_Niveau_3",
    v."NomNiveau_3",
    NULL::integer AS "ID_Niveau_4",
    NULL::character varying AS "NomNiveau_4",
    c."AdresseTerritoire",
    c."TelephoneTerritoire",
    c."TelephoneSecondaireTerritoire",
    c."EmailTerritoire",
    c."SiteWebTerritoire",
    c."InformationsAccueilTerritoire",
    c."HorairesOuvertureTerritoire",
    (c."ID_CoordonneesTerritoire" IS NOT NULL) AS "CoordonneesPubliees"
   FROM (((geolocalisation."V_Niveau_3" v
     JOIN referentiel."T_Generique" g ON (((g."ID_Generique" = v."ID_TypeNiveau_2_Fk") AND (g."ValideGenerique" IS TRUE) AND (g."IdEntiteFk" IS NULL) AND (g."ID_CategorieGeneriqueFk" = ANY (referentiel.fn_categories_champ('geolocalisation'::text, 'T_Niveau_3'::text, 'ID_TypeNiveau_2_Fk'::text, NULL::integer))))))
     JOIN referentiel."T_CategorieGenerique" cat ON (((cat."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk") AND (cat."ValideCategorieGenerique" IS TRUE) AND (cat."IdEntiteFk" IS NULL))))
     LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON (((c."ID_Niveau_3Fk" = v."ID_Niveau_3") AND (c."PublierCoordonneesAnnuaire" IS TRUE))))
UNION ALL
 SELECT ('n4:'::text || (v."ID_Niveau_4")::text) AS "StructureKey",
    4 AS "NiveauStructure",
    v."ID_Niveau_4" AS "ID_Structure",
    v."NomNiveau_4" AS "NomStructure",
    v."CodeNiveau_4" AS "CodeStructure",
    g."ID_Generique" AS "ID_TypeStructureFk",
    COALESCE(NULLIF(btrim((g."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (g."ID_Generique")::text)) AS "TypeStructure",
    v."ID_Niveau_1",
    v."NomNiveau_1",
    v."ID_Niveau_2",
    v."NomNiveau_2",
    v."ID_Niveau_3",
    v."NomNiveau_3",
    v."ID_Niveau_4",
    v."NomNiveau_4",
    c."AdresseTerritoire",
    c."TelephoneTerritoire",
    c."TelephoneSecondaireTerritoire",
    c."EmailTerritoire",
    c."SiteWebTerritoire",
    c."InformationsAccueilTerritoire",
    c."HorairesOuvertureTerritoire",
    (c."ID_CoordonneesTerritoire" IS NOT NULL) AS "CoordonneesPubliees"
   FROM (((geolocalisation."V_Niveau_4" v
     JOIN referentiel."T_Generique" g ON (((g."ID_Generique" = v."ID_TypeNiveau_4_Fk") AND (g."ValideGenerique" IS TRUE) AND (g."IdEntiteFk" IS NULL) AND (g."ID_CategorieGeneriqueFk" = ANY (referentiel.fn_categories_champ('geolocalisation'::text, 'T_Niveau_4'::text, 'ID_TypeNiveau_4_Fk'::text, NULL::integer))))))
     JOIN referentiel."T_CategorieGenerique" cat ON (((cat."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk") AND (cat."ValideCategorieGenerique" IS TRUE) AND (cat."IdEntiteFk" IS NULL))))
     LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON (((c."ID_Niveau_4Fk" = v."ID_Niveau_4") AND (c."PublierCoordonneesAnnuaire" IS TRUE))))
UNION ALL
 SELECT ('n5:'::text || (v."ID_Niveau_5")::text) AS "StructureKey",
    5 AS "NiveauStructure",
    v."ID_Niveau_5" AS "ID_Structure",
    v."NomNiveau_5" AS "NomStructure",
    v."CodeNiveau_5" AS "CodeStructure",
    g."ID_Generique" AS "ID_TypeStructureFk",
    COALESCE(NULLIF(btrim((g."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (g."ID_Generique")::text)) AS "TypeStructure",
    v."ID_Niveau_1",
    v."NomNiveau_1",
    v."ID_Niveau_2",
    v."NomNiveau_2",
    v."ID_Niveau_3",
    v."NomNiveau_3",
    v."ID_Niveau_4",
    v."NomNiveau_4",
    c."AdresseTerritoire",
    c."TelephoneTerritoire",
    c."TelephoneSecondaireTerritoire",
    c."EmailTerritoire",
    c."SiteWebTerritoire",
    c."InformationsAccueilTerritoire",
    c."HorairesOuvertureTerritoire",
    (c."ID_CoordonneesTerritoire" IS NOT NULL) AS "CoordonneesPubliees"
   FROM (((geolocalisation."V_Niveau_5" v
     JOIN referentiel."T_Generique" g ON (((g."ID_Generique" = v."ID_TypeNiveau_5_Fk") AND (g."ValideGenerique" IS TRUE) AND (g."IdEntiteFk" IS NULL) AND (g."ID_CategorieGeneriqueFk" = ANY (referentiel.fn_categories_champ('geolocalisation'::text, 'T_Niveau_5'::text, 'ID_TypeNiveau_5_Fk'::text, NULL::integer))))))
     JOIN referentiel."T_CategorieGenerique" cat ON (((cat."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk") AND (cat."ValideCategorieGenerique" IS TRUE) AND (cat."IdEntiteFk" IS NULL))))
     LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON (((c."ID_Niveau_5Fk" = v."ID_Niveau_5") AND (c."PublierCoordonneesAnnuaire" IS TRUE))));

--
-- Name: VIEW "V_StructureSanitairePublique"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_StructureSanitairePublique" IS 'Annuaire des structures et territoires fermé au grain niveau 3/4/5 + identifiant territorial, distinct des entreprises ERP. Tous les types territoriaux communs actifs de la famille physique actuellement résolue sont admis, y compris districts, secteurs et groupements ; aucune sélection médicale implicite ni filtre sur VisibleNiveau pour masquer les affectations historiques. Les contacts et horaires déclarés sont NULL sans publication explicite de la fiche associée. Exclut GPS, comptes, observations, populations, géométries, déploiement, auteurs, logos, offres et affiliations. Les API imposent session et module Structures ; aucune permission anonyme ou messagerie n’est accordée. Ne prouve ni agrément, disponibilité ou permanence.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."StructureKey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."StructureKey" IS 'Clé stable composite n3:<id>, n4:<id> ou n5:<id>. Ne désigne jamais une entreprise ERP ou un destinataire de discussion.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."NiveauStructure"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."NiveauStructure" IS 'Niveau territorial source : 3, 4 ou 5 ; composant obligatoire de l’identité.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."ID_Structure"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."ID_Structure" IS 'Identifiant physique du territoire dans son niveau source ; seul, il n’est pas unique entre niveaux.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."NomStructure"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."NomStructure" IS 'Nom territorial enregistré, éventuellement absent ; aucune dénomination d’entreprise n’est déduite.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."CodeStructure"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."CodeStructure" IS 'Code territorial facultatif déclaré, sans unicité mondiale supposée.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."ID_TypeStructureFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."ID_TypeStructureFk" IS 'Identifiant T_Generique du vrai champ de type du territoire, actif, commun et appartenant à la famille physique actuellement résolue. Aucun classement médical supplémentaire.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."TypeStructure"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."TypeStructure" IS 'AbrGenerique du type central ; si absente, libellé neutre identifié. NomGenerique ne remplace jamais l’abréviation.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."ID_Niveau_1" IS 'Identifiant de province issu de la hiérarchie territoriale commune, éventuellement absent.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."NomNiveau_1" IS 'Nom de province issu de la vue territoriale commune, sans déduction de visibilité ou publication.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."ID_Niveau_2" IS 'Identifiant de subdivision ou antenne réellement rattachée, éventuellement absent.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."NomNiveau_2" IS 'Nom de subdivision ou antenne issu de la hiérarchie commune.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."ID_Niveau_3" IS 'Identifiant du niveau 3 : propre territoire N3 ou zone effective de la vue N4/N5 ; N5 conserve COALESCE(zone directe, zone de l’aire).';

--
-- Name: COLUMN "V_StructureSanitairePublique"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."NomNiveau_3" IS 'Nom du niveau 3 issu de la même hiérarchie que son identifiant.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."ID_Niveau_4" IS 'Identifiant propre du territoire N4 ou de l’aire réellement liée au N5 ; NULL pour une entrée N3.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."NomNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."NomNiveau_4" IS 'Nom du niveau 4 réellement lié, NULL pour une entrée N3 ou sans aire.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."AdresseTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."AdresseTerritoire" IS 'Adresse institutionnelle déclarée pour cette seule entrée ; NULL sans consentement explicite, sans héritage de parent.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."TelephoneTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."TelephoneTerritoire" IS 'Téléphone institutionnel principal déclaré et explicitement publié ; NULL sinon.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."TelephoneSecondaireTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."TelephoneSecondaireTerritoire" IS 'Téléphone institutionnel secondaire déclaré et explicitement publié ; NULL sinon.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."EmailTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."EmailTerritoire" IS 'Adresse e-mail institutionnelle déclarée et explicitement publiée ; NULL sinon.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."SiteWebTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."SiteWebTerritoire" IS 'Site web institutionnel déclaré et explicitement publié ; NULL sinon, sans agrément implicite.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."InformationsAccueilTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."InformationsAccueilTerritoire" IS 'Informations d’accueil en texte simple explicitement publiées ; NULL sinon, sans permanence déduite.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."HorairesOuvertureTerritoire"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."HorairesOuvertureTerritoire" IS 'Horaires déclarés en texte simple explicitement publiés ; NULL si absents ou non publiés, aucun calcul d’ouverture actuelle.';

--
-- Name: COLUMN "V_StructureSanitairePublique"."CoordonneesPubliees"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique"."CoordonneesPubliees" IS 'True seulement lorsqu’une fiche de coordonnées du territoire porte le consentement explicite. Ne garantit ni complétude ni vérification métier.';
