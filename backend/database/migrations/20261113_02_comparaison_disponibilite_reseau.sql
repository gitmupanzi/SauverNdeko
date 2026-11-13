CREATE FUNCTION geolocalisation.fn_aire_avec_reseau(abreviation text)
RETURNS boolean
LANGUAGE sql IMMUTABLE PARALLEL SAFE
SET search_path = pg_catalog
AS $fonction$
    SELECT COALESCE(lower(abreviation COLLATE pg_catalog."unicode") NOT IN ('sans reseau', 'sans réseau'), false)
$fonction$;

COMMENT ON FUNCTION geolocalisation.fn_aire_avec_reseau(text)
IS 'Reconnaît les deux abréviations de réseau absent quelle que soit leur casse. Une valeur NULL ne déclare aucun réseau.';

DO $droits$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'sauverndeko_runtime') THEN
        GRANT EXECUTE ON FUNCTION geolocalisation.fn_aire_avec_reseau(text) TO sauverndeko_runtime;
    END IF;
END
$droits$;

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_4" AS
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
                    geolocalisation.fn_aire_avec_reseau(g_reseau."AbrGenerique") AS "AvecReseau"
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

COMMENT ON VIEW geolocalisation."V_Niveau_4"
IS 'Référentiel territorial partagé du niveau 4 avec rattachements, compteurs exacts des sites enfants et disponibilité déclarée du réseau.';

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AvecReseau"
IS 'Indique un réseau renseigné, hors des abréviations « Sans reseau » et « Sans réseau » comparées sans tenir compte de la casse.';

CREATE OR REPLACE VIEW geolocalisation."V_RESEAU_AS_par_ZS" AS
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
            WHEN geolocalisation.fn_aire_avec_reseau(g_reseau."AbrGenerique") THEN 1
            ELSE 0
        END) AS "Nb_AS_Avec_Reseau",
    round(((100.0 * (sum(
        CASE
            WHEN geolocalisation.fn_aire_avec_reseau(g_reseau."AbrGenerique") THEN 1
            ELSE 0
        END))::numeric) / (NULLIF(count(n4."ID_Niveau_4"), 0))::numeric), 1) AS "Pct_AS_Avec_Reseau"
   FROM (((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3";

COMMENT ON VIEW geolocalisation."V_RESEAU_AS_par_ZS"
IS 'Nombre et part des aires avec réseau déclaré par zone, suivant la même comparaison que la liste détaillée des aires.';

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."Nb_AS_Avec_Reseau"
IS 'Nombre des aires avec un réseau déclaré selon la même règle que V_Niveau_4.AvecReseau.';

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."Pct_AS_Avec_Reseau"
IS 'Pourcentage des aires avec un réseau déclaré, arrondi à une décimale. Affiche NULL quand la zone ne contient aucune aire.';
