-- View: geolocalisation.V_AS_sans_Site
-- DROP VIEW geolocalisation."V_AS_sans_Site";
CREATE OR REPLACE VIEW geolocalisation."V_AS_sans_Site" AS
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
FROM geolocalisation."T_Niveau_4" n4
    LEFT JOIN geolocalisation."T_Niveau_3" n3 ON n4."ID_Niveau_3_Fk" = n3."ID_Niveau_3"
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
    LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN geolocalisation."T_Niveau_5" n5 ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
GROUP BY n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_Niveau_4",
    n4."NomNiveau_4"
HAVING count(n5."ID_Niveau_5") = 0;
ALTER TABLE geolocalisation."V_AS_sans_Site" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_AS_sans_Site" IS 'Vue de controle qualite : Aires de Sante (Niveau 4) sans structure ou site (Niveau 5).';
-- View: geolocalisation.V_Niveau_0
-- DROP VIEW geolocalisation."V_Niveau_0";
CREATE OR REPLACE VIEW geolocalisation."V_Niveau_0" AS
SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n0."CodeNiveau_0",
    n0."geometryNiveau_0"
FROM geolocalisation."T_Niveau_0" n0;
ALTER TABLE geolocalisation."V_Niveau_0" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Niveau_0" IS 'Vue de reference du Niveau 0 : nom, code et geometrie.';
-- View: geolocalisation.V_Niveau_1_Old
-- DROP VIEW geolocalisation."V_Niveau_1_Old";
CREATE OR REPLACE VIEW geolocalisation."V_Niveau_1_Old" AS
SELECT n1o."ID_Niveau_1_Old",
    n1o."NomNiveau_1_Old",
    n1o."geometryNiveau_1_Old",
    n1o."surfaceNiveau_1_Old"
FROM geolocalisation."T_Niveau_1_Old" n1o;
ALTER TABLE geolocalisation."V_Niveau_1_Old" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Niveau_1_Old" IS 'Vue de reference de l''ancien Niveau 1 pour les correspondances historiques.';
-- View: geolocalisation.V_Niveau_1
-- DROP VIEW geolocalisation."V_Niveau_1";
CREATE OR REPLACE VIEW geolocalisation."V_Niveau_1" AS
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
FROM geolocalisation."T_Niveau_1" n1a
    LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0";
ALTER TABLE geolocalisation."V_Niveau_1" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Niveau_1" IS 'Vue de reference du Niveau 1 avec rattachement au Niveau 0 et a l''ancien Niveau 1.';
-- View: geolocalisation.V_Niveau_2
-- DROP VIEW geolocalisation."V_Niveau_2";
CREATE OR REPLACE VIEW geolocalisation."V_Niveau_2" AS
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
FROM geolocalisation."T_Niveau_2" n2
    LEFT JOIN geolocalisation."T_Niveau_1" n1a ON n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old"
    LEFT JOIN referentiel."T_Generique" g_type ON n2."ID_TypeNiveau_2_Fk" = g_type."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_statut ON n2."ID_StatutNiveau_2" = g_statut."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_deploi ON n2."ID_StatusDeploiFk" = g_deploi."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_voie ON n2."ID_VoieAccesDPSANTFk" = g_voie."ID_Generique";
ALTER TABLE geolocalisation."V_Niveau_2" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Niveau_2" IS 'Vue de reference du Niveau 2 avec contexte hierarchique, type, statut, deploiement et voie d''acces.';
-- View: geolocalisation.V_Niveau_3
-- DROP VIEW geolocalisation."V_Niveau_3";
CREATE OR REPLACE VIEW geolocalisation."V_Niveau_3" AS
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
    COALESCE(
        g_deploiement."AbrGenerique",
        ' '::character varying
    ) AS "Statut_Deploiement",
    n3."KmAntenneBCZS",
    n3."ID_VoieAccesANTBCZFk",
    COALESCE(g_voie1."AbrGenerique", ' '::character varying) AS "Voie_ANTBCZ",
    n3."KmDPSBCZS",
    n3."ID_VoieAccesDPSBCZFk",
    COALESCE(g_voie2."AbrGenerique", ' '::character varying) AS "Voie_DPSBCZS",
    n3."SelectNiveau_3",
    n3."ID_Niveau_2_FK"
FROM geolocalisation."T_Niveau_3" n3
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
    LEFT JOIN geolocalisation."T_Niveau_1" n1a ON n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN referentiel."T_Generique" g_type ON n3."ID_TypeNiveau_2_Fk" = g_type."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_statut ON n3."ID_StatutNiveau_3_Fk" = g_statut."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_deploiement ON n3."ID_StatutDeploieFk" = g_deploiement."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_voie1 ON n3."ID_VoieAccesANTBCZFk" = g_voie1."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_voie2 ON n3."ID_VoieAccesDPSBCZFk" = g_voie2."ID_Generique";
ALTER TABLE geolocalisation."V_Niveau_3" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Niveau_3" IS 'Vue de reference du Niveau 3 avec type, statut, deploiement, distances et voies d''acces.';
-- View: geolocalisation.V_Niveau_4
-- DROP VIEW geolocalisation."V_Niveau_4";
CREATE OR REPLACE VIEW geolocalisation."V_Niveau_4" AS
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
    (
        COALESCE(g_type."AbrGenerique", ''::character varying)::text || ' '::text
    ) || COALESCE(n4."NomNiveau_4", ''::character varying)::text AS "SITE",
    n4."CodeNiveau_4",
    n4."PopulationNiveau_4",
    n4."LatitudeNiveau_4",
    n4."LongitudeNiveau_4",
    n4."AltitudeNiveau_4",
    n4."geometryNiveau_4",
    COALESCE(g_reseau."AbrGenerique", ' '::character varying) AS "RESEAU",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "VOIE_AS_ZS",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "STATUT_AS",
    COALESCE(
        g_deploiement."AbrGenerique",
        ' '::character varying
    ) AS "STATUT_DEPLOI",
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
FROM geolocalisation."T_Niveau_4" n4
    LEFT JOIN geolocalisation."T_Niveau_3" n3 ON n4."ID_Niveau_3_Fk" = n3."ID_Niveau_3"
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
    LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN referentiel."T_Generique" g_type ON n4."ID_TypeNiveau_4_Fk" = g_type."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_reseau ON n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_voie ON n4."ID_VoieAccesZsASFk" = g_voie."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_statut ON n4."ID_StatutNiveau_4" = g_statut."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_deploiement ON n4."ID_StatutDeploiementFk" = g_deploiement."ID_Generique"
ORDER BY n0."NomNiveau_0",
    n1."NomNiveau_1",
    n2."NomNiveau_2",
    n3."NomNiveau_3",
    n4."NomNiveau_4";
ALTER TABLE geolocalisation."V_Niveau_4" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Niveau_4" IS 'Vue de reference du Niveau 4 avec hierarchie complete, identifiant de ligne, nom brut et indicateurs reseau/statut.';
-- View: geolocalisation.V_Niveau_5
-- DROP VIEW geolocalisation."V_Niveau_5";
CREATE OR REPLACE VIEW geolocalisation."V_Niveau_5" AS
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
    (
        COALESCE(g_type."AbrGenerique", ''::character varying)::text || ' '::text
    ) || COALESCE(n5."NomNiveau_5", ''::character varying)::text AS "SITE",
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
    COALESCE(
        g_deploiement."AbrGenerique",
        ' '::character varying
    ) AS "STATUT_DEPLOI",
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
FROM geolocalisation."T_Niveau_5" n5
    LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n5."ID_Niveau_4_Fk" = n4."ID_Niveau_4"
    LEFT JOIN geolocalisation."T_Niveau_3" n3 ON COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk") = n3."ID_Niveau_3"
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
    LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN referentiel."T_Generique" g_type ON n5."ID_TypeNiveau_5_Fk" = g_type."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_reseau ON n5."ID_DispoReseauNiveau_5" = g_reseau."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_voie ON n5."ID_VoieAccesZsSiteFk" = g_voie."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_statut ON n5."ID_StatutNiveau_5" = g_statut."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_deploiement ON n5."ID_StatutDeploiementFk" = g_deploiement."ID_Generique"
ORDER BY n0."NomNiveau_0",
    n1."NomNiveau_1",
    n2."NomNiveau_2",
    n3."NomNiveau_3",
    n5."NomNiveau_5";
ALTER TABLE geolocalisation."V_Niveau_5" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Niveau_5" IS 'Vue de reference du Niveau 5 avec identifiants de ligne, nom brut, reseau, statut et informations de site.';
-- View: geolocalisation.V_Pop_N3_Couverte_Sites
-- DROP VIEW geolocalisation."V_Pop_N3_Couverte_Sites";
CREATE OR REPLACE VIEW geolocalisation."V_Pop_N3_Couverte_Sites" AS
SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n5."ID_TypeNiveau_5_Fk",
    COALESCE(g_type5."AbrGenerique", ' '::character varying) AS "Type_Niveau_5",
    sum(COALESCE(n5."PopulationNiveau_5", 0::numeric)) AS "Pop_Cum_Sites"
FROM geolocalisation."T_Niveau_3" n3
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
    LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
    LEFT JOIN geolocalisation."T_Niveau_5" n5 ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
    LEFT JOIN referentiel."T_Generique" g_type5 ON n5."ID_TypeNiveau_5_Fk" = g_type5."ID_Generique"
GROUP BY n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n5."ID_TypeNiveau_5_Fk",
    g_type5."AbrGenerique";
ALTER TABLE geolocalisation."V_Pop_N3_Couverte_Sites" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Pop_N3_Couverte_Sites" IS 'Vue d''indicateurs population : somme des populations des sites par Zone de Sante et type de structure.';
-- View: geolocalisation.V_RESEAU_AS_par_ZS
-- DROP VIEW geolocalisation."V_RESEAU_AS_par_ZS";
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
            WHEN g_reseau."AbrGenerique" IS NOT NULL
            AND g_reseau."AbrGenerique"::text <> 'Sans reseau'::text THEN 1
            ELSE 0
        END
    ) AS "Nb_AS_Avec_Reseau",
    round(
        100.0 * sum(
            CASE
                WHEN g_reseau."AbrGenerique" IS NOT NULL
                AND g_reseau."AbrGenerique"::text <> 'Sans reseau'::text THEN 1
                ELSE 0
            END
        )::numeric / NULLIF(count(n4."ID_Niveau_4"), 0)::numeric,
        1
    ) AS "Pct_AS_Avec_Reseau"
FROM geolocalisation."T_Niveau_3" n3
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
    LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
    LEFT JOIN referentiel."T_Generique" g_reseau ON n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique"
GROUP BY n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3";
ALTER TABLE geolocalisation."V_RESEAU_AS_par_ZS" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_RESEAU_AS_par_ZS" IS 'Vue d''indicateurs connectivite : nombre et pourcentage d''Aires de Sante avec reseau par Zone de Sante.';
-- View: geolocalisation.V_Stats_N1_N2
-- DROP VIEW geolocalisation."V_Stats_N1_N2";
CREATE OR REPLACE VIEW geolocalisation."V_Stats_N1_N2" AS
SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_TypeNiveau_2_Fk",
    COALESCE(g_type2."AbrGenerique", ' '::character varying) AS "Type_Niveau_2",
    count(DISTINCT n2."ID_Niveau_2") AS "Nb_Niveau_2",
    sum(COALESCE(n2."PopulationNiveau_2", 0::numeric)) AS "Pop_Niveau_2"
FROM geolocalisation."T_Niveau_1" n1
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n1."ID_Niveau_1" = n2."ID_Niveau_1_FK"
    LEFT JOIN referentiel."T_Generique" g_type2 ON n2."ID_TypeNiveau_2_Fk" = g_type2."ID_Generique"
GROUP BY n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_TypeNiveau_2_Fk",
    g_type2."AbrGenerique";
ALTER TABLE geolocalisation."V_Stats_N1_N2" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Stats_N1_N2" IS 'Vue d''indicateurs structurels : nombre d''unites de Niveau 2 et population de Niveau 2 par Niveau 1 et type.';
-- View: geolocalisation.V_Stats_N3_Structures
-- DROP VIEW geolocalisation."V_Stats_N3_Structures";
CREATE OR REPLACE VIEW geolocalisation."V_Stats_N3_Structures" AS
SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_TypeNiveau_4_Fk",
    COALESCE(g_type4."AbrGenerique", ' '::character varying) AS "Type_Niveau_4",
    n5."ID_TypeNiveau_5_Fk",
    COALESCE(g_type5."AbrGenerique", ' '::character varying) AS "Type_Niveau_5",
    count(DISTINCT n4."ID_Niveau_4") AS "Nb_Aires_Sante",
    count(DISTINCT n5."ID_Niveau_5") AS "Nb_Structures_Sante"
FROM geolocalisation."T_Niveau_3" n3
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
    LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
    LEFT JOIN geolocalisation."T_Niveau_5" n5 ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
    LEFT JOIN referentiel."T_Generique" g_type4 ON n4."ID_TypeNiveau_4_Fk" = g_type4."ID_Generique"
    LEFT JOIN referentiel."T_Generique" g_type5 ON n5."ID_TypeNiveau_5_Fk" = g_type5."ID_Generique"
GROUP BY n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_TypeNiveau_4_Fk",
    g_type4."AbrGenerique",
    n5."ID_TypeNiveau_5_Fk",
    g_type5."AbrGenerique";
ALTER TABLE geolocalisation."V_Stats_N3_Structures" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_Stats_N3_Structures" IS 'Vue d''indicateurs par Zone de Sante et par type : Aires de Sante et structures de sante.';
-- View: geolocalisation.V_ZS_sans_AS
-- DROP VIEW geolocalisation."V_ZS_sans_AS";
CREATE OR REPLACE VIEW geolocalisation."V_ZS_sans_AS" AS
SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3"
FROM geolocalisation."T_Niveau_3" n3
    LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
    LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
    LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
    LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
GROUP BY n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3"
HAVING count(n4."ID_Niveau_4") = 0;
ALTER TABLE geolocalisation."V_ZS_sans_AS" OWNER TO postgres;
COMMENT ON VIEW geolocalisation."V_ZS_sans_AS" IS 'Vue de controle qualite : Zones de Sante (Niveau 3) sans Aire de Sante (Niveau 4).';