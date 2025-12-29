BEGIN;

-- ===========================
-- DROP EXISTING VIEWS (analyses + niveaux)
-- ===========================

DROP VIEW IF EXISTS geolocalisation."V_AS_sans_Site";
DROP VIEW IF EXISTS geolocalisation."V_ZS_sans_AS";
DROP VIEW IF EXISTS geolocalisation."V_RESEAU_AS_par_ZS";
DROP VIEW IF EXISTS geolocalisation."V_Pop_N3_Couverte_Sites";
DROP VIEW IF EXISTS geolocalisation."V_Stats_N3_Structures";
DROP VIEW IF EXISTS geolocalisation."V_Stats_N1_N2";
DROP VIEW IF EXISTS geolocalisation."V_Niveau_5";
DROP VIEW IF EXISTS geolocalisation."V_Niveau_4";
DROP VIEW IF EXISTS geolocalisation."V_Niveau_3";
DROP VIEW IF EXISTS geolocalisation."V_Niveau_2";
DROP VIEW IF EXISTS geolocalisation."V_Niveau_1";

-- ===========================
-- V_Niveau_1
-- ===========================

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_1" AS
SELECT 
    n1a."ID_Niveau_0_Fk",
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
    n1a."SurfaceNiveau_1",
    n1a."geometryNiveau_1",
    n1a."EtenduNiveau_1",
    n1a."timezoneNiveau_1",
    n1a."wikidataNiveau_1",
    n1a."FusionNiveau_1",
    n1a."VisibleNiveau_1",
    n1a."VisibleNiveau_5",
    n1a."ObsNiveau_1"
FROM geolocalisation."T_Niveau_1" n1a
LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b 
    ON n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old"
LEFT JOIN geolocalisation."T_Niveau_0" n0 
    ON n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0";

ALTER TABLE geolocalisation."V_Niveau_1" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_Niveau_1" IS
'Vue de référence du Niveau 1 (Province/DPS) incluant :
- le lien vers le Niveau 0 (pays/entité supérieure)
- le lien vers l''ancien Niveau 1 (Niveau_1_Old)
- les attributs de base (codes, population, coordonnées, visibilité, etc.).';

-- ===========================
-- V_Niveau_2 (Antenne PEV, etc.)
-- ===========================

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_2" AS
SELECT 
    n0."NomNiveau_0",
    n1b."NomNiveau_1_Old",
    n2."ID_Niveau_1_FK",
    n1a."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."ID_TypeNiveau_2_Fk",
    COALESCE(g_type."AbrGenerique",' ') AS "Type_Niveau_2",
    n2."NomNiveau_2",
    n2."Alt1_NomNiveau_2",
    n2."AbreNiveau_2",
    n2."CodeNiveau_2",
    n2."PopulationNiveau_2",
    n2."LatitudeNiveau_2",
    n2."LongitudeNiveau_2",
    n2."AltitudeNiveau_2",
    n2."geometryNiveau_2",
    n2."SurfaceNiveau_2",
    n2."EtenduNiveau_2",
    n2."ObsNiveau_2",
    n2."ID_StatutNiveau_2",
    COALESCE(g_statut."AbrGenerique",' ') AS "Statut_Niveau_2",
    n2."ID_StatusDeploiFk",
    COALESCE(g_deploi."AbrGenerique",' ') AS "Statut_Deploiement",
    n2."KmDPSANT",
    n2."ID_VoieAccesDPSANTFk",
    COALESCE(g_voie."AbrGenerique",' ') AS "Voie_Acces_DPS",
    n2."SelectNiveau_2"
FROM geolocalisation."T_Niveau_0" n0
JOIN geolocalisation."T_Niveau_1" n1a 
    ON n0."ID_Niveau_0" = n1a."ID_Niveau_0_Fk"
JOIN geolocalisation."T_Niveau_2" n2 
    ON n1a."ID_Niveau_1" = n2."ID_Niveau_1_FK"
LEFT JOIN referentiel."T_Generique" g_type 
    ON n2."ID_TypeNiveau_2_Fk" = g_type."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_statut 
    ON n2."ID_StatutNiveau_2" = g_statut."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_deploi 
    ON n2."ID_StatusDeploiFk" = g_deploi."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_voie 
    ON n2."ID_VoieAccesDPSANTFk" = g_voie."ID_Generique"
LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b 
    ON n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old";

ALTER TABLE geolocalisation."V_Niveau_2" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_Niveau_2" IS
'Vue de référence du Niveau 2 (ex. Antenne PEV / niveau intermédiaire) incluant :
- le contexte hiérarchique (Niveau 0 et Niveau 1, ancien et nouveau)
- le type, le statut, le statut de déploiement et la voie d''accès
- les informations de population, coordonnées et géométrie.';

-- ===========================
-- V_Niveau_3 (Zone de Santé)
-- ===========================

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_3" AS
SELECT 
    n3."ID_TypeNiveau_2_Fk",
    COALESCE(g_type."AbrGenerique",' ') AS "Type_Niveau_3",
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
    n3."SurfaceNiveau_3",
    n3."geometryNiveau_3",
    n3."ObsNiveau_3",
    n3."ID_StatutNiveau_3_Fk",
    COALESCE(g_statut."AbrGenerique",' ') AS "Statut_Niveau_3",
    n3."ID_StatutDeploieFk",
    COALESCE(g_deploiement."AbrGenerique",' ') AS "Statut_Deploiement",
    n3."KmAntenneBCZS",
    n3."ID_VoieAccesANTBCZFk",
    COALESCE(g_voie1."AbrGenerique",' ') AS "Voie_ANTBCZ",
    n3."KmDPSBCZS",
    n3."ID_VoieAccesDPSBCZFk",
    COALESCE(g_voie2."AbrGenerique",' ') AS "Voie_DPSBCZS",
    n3."SelectNiveau_3"
FROM geolocalisation."T_Niveau_3" n3
JOIN geolocalisation."T_Niveau_2" n2 
    ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
JOIN geolocalisation."T_Niveau_1" n1a 
    ON n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1"
JOIN geolocalisation."T_Niveau_0" n0 
    ON n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
LEFT JOIN referentiel."T_Generique" g_type 
    ON n3."ID_TypeNiveau_2_Fk" = g_type."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_statut 
    ON n3."ID_StatutNiveau_3_Fk" = g_statut."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_deploiement 
    ON n3."ID_StatutDeploieFk" = g_deploiement."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_voie1 
    ON n3."ID_VoieAccesANTBCZFk" = g_voie1."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_voie2 
    ON n3."ID_VoieAccesDPSBCZFk" = g_voie2."ID_Generique";

ALTER TABLE geolocalisation."V_Niveau_3" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_Niveau_3" IS
'Vue de référence du Niveau 3 (Zone de Santé) incluant :
- le type, le statut et le statut de déploiement
- les distances et voies d''accès (antenne BCZS, DPS)
- les attributs de population, géométrie et métadonnées.';

-- ===========================
-- V_Niveau_4 (Aire de Santé)
-- ===========================

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_4" AS
SELECT 
    n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_TypeNiveau_4_Fk",
    COALESCE(g_type."AbrGenerique",'') AS "Type_Niveau_4",
    n4."AbreNiveau_4",
    (COALESCE(g_type."AbrGenerique",'') || ' ' || COALESCE(n4."NomNiveau_4",'')) AS "SITE",
    n4."CodeNiveau_4",
    n4."PopulationNiveau_4",
    n4."LatitudeNiveau_4",
    n4."LongitudeNiveau_4",
    n4."AltitudeNiveau_4",
    n4."geometryNiveau_4",
    COALESCE(g_reseau."AbrGenerique",' ') AS "RESEAU",
    COALESCE(g_voie."AbrGenerique",' ') AS "VOIE_AS_ZS",
    COALESCE(g_statut."AbrGenerique",' ') AS "STATUT_AS",
    COALESCE(g_deploiement."AbrGenerique",' ') AS "STATUT_DEPLOI",
    n3."KmAntenneBCZS",
    n3."KmDPSBCZS",
    n4."ObsNiveau_4",
    n4."SelectNiveau_4"
FROM geolocalisation."T_Niveau_3" n3
JOIN geolocalisation."T_Niveau_2" n2 
    ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
JOIN geolocalisation."T_Niveau_1" n1 
    ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
JOIN geolocalisation."T_Niveau_0" n0 
    ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
JOIN geolocalisation."T_Niveau_4" n4 
    ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
LEFT JOIN referentiel."T_Generique" g_type 
    ON n4."ID_TypeNiveau_4_Fk" = g_type."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_reseau 
    ON n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_voie 
    ON n4."ID_VoieAccesZsASFk" = g_voie."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_statut 
    ON n4."ID_StatutNiveau_4" = g_statut."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_deploiement 
    ON n4."ID_StatutDeploiementFk" = g_deploiement."ID_Generique"
ORDER BY n0."NomNiveau_0";

ALTER TABLE geolocalisation."V_Niveau_4" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_Niveau_4" IS
'Vue de référence du Niveau 4 (Aire de Santé) incluant :
- toute la hiérarchie administrative (Niveaux 0 à 3)
- le type d''Aire, le réseau, la voie d''accès, le statut et le statut de déploiement
- les attributs de site (population, géométrie, code, etc.).';

-- ===========================
-- V_Niveau_5 (Structure de santé / site)
-- ===========================

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_5" AS
SELECT 
    n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n5."ID_TypeNiveau_5_Fk",
    COALESCE(g_type."AbrGenerique",'') AS "Type_Niveau_5",
    (COALESCE(g_type."AbrGenerique",'') || ' ' || COALESCE(n5."NomNiveau_5",'')) AS "SITE",
    n5."AbreNiveau_5",
    n5."CodeNiveau_5",
    n5."PopulationNiveau_5",
    n5."LongitudeNiveau_5",
    n5."LatitudeNiveau_5",
    n5."AltitudeNiveau_5",
    n5."geometryNiveau_5",
    COALESCE(g_reseau."AbrGenerique",' ') AS "RESEAU",
    COALESCE(g_voie."AbrGenerique",' ') AS "VOIE_AS_Site",
    COALESCE(g_statut."AbrGenerique",' ') AS "STATUT_Site",
    COALESCE(g_deploiement."AbrGenerique",' ') AS "STATUT_DEPLOI",
    n3."KmAntenneBCZS",
    n3."KmDPSBCZS"
FROM geolocalisation."T_Niveau_3" n3
JOIN geolocalisation."T_Niveau_2" n2 
    ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
JOIN geolocalisation."T_Niveau_1" n1 
    ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
JOIN geolocalisation."T_Niveau_0" n0 
    ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
JOIN geolocalisation."T_Niveau_4" n4 
    ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
JOIN geolocalisation."T_Niveau_5" n5 
    ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
LEFT JOIN referentiel."T_Generique" g_type 
    ON n5."ID_TypeNiveau_5_Fk" = g_type."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_reseau 
    ON n5."ID_DispoReseauNiveau_5" = g_reseau."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_voie 
    ON n5."ID_VoieAccesZsSiteFk" = g_voie."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_statut 
    ON n5."ID_StatutNiveau_5" = g_statut."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_deploiement 
    ON n5."ID_StatutDeploiementFk" = g_deploiement."ID_Generique"
ORDER BY n0."NomNiveau_0";

ALTER TABLE geolocalisation."V_Niveau_5" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_Niveau_5" IS
'Vue de référence du Niveau 5 (Structure de santé / site) incluant :
- toute la hiérarchie administrative (Niveaux 0 à 4)
- le type de structure, le réseau, la voie d''accès, le statut et le statut de déploiement
- les attributs détaillés de site (population, coordonnées, géométrie, etc.).';

-- ==========================================================
-- VUES D'ANALYSE / INDICATEURS (AVEC TYPES)
-- ==========================================================

-- 1) Nb de N2 + population N2 par N1 ET par type de Niveau 2
CREATE OR REPLACE VIEW geolocalisation."V_Stats_N1_N2" AS
SELECT
  n0."ID_Niveau_0",
  n0."NomNiveau_0",
  n1."ID_Niveau_1",
  n1."NomNiveau_1",
  n2."ID_TypeNiveau_2_Fk",
  COALESCE(g_type2."AbrGenerique",' ') AS "Type_Niveau_2",
  COUNT(DISTINCT n2."ID_Niveau_2") AS "Nb_Niveau_2",
  SUM(COALESCE(n2."PopulationNiveau_2",0)) AS "Pop_Niveau_2"
FROM geolocalisation."T_Niveau_1" n1
JOIN geolocalisation."T_Niveau_0" n0
  ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
LEFT JOIN geolocalisation."T_Niveau_2" n2
  ON n1."ID_Niveau_1" = n2."ID_Niveau_1_FK"
LEFT JOIN referentiel."T_Generique" g_type2
  ON n2."ID_TypeNiveau_2_Fk" = g_type2."ID_Generique"
GROUP BY 
  n0."ID_Niveau_0", n0."NomNiveau_0",
  n1."ID_Niveau_1", n1."NomNiveau_1",
  n2."ID_TypeNiveau_2_Fk", g_type2."AbrGenerique";

ALTER TABLE geolocalisation."V_Stats_N1_N2" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_Stats_N1_N2" IS
'Vue d''indicateurs structurels : nombre d''unités de Niveau 2 et population totale du Niveau 2
pour chaque entité de Niveau 1 (Province/DPS) ET par type de Niveau 2 (Antenne PEV, etc.).';

-- 2) Nb d''aires (N4) et de structures (N5) par ZS (N3) ET par type
CREATE OR REPLACE VIEW geolocalisation."V_Stats_N3_Structures" AS
SELECT
  n0."ID_Niveau_0",
  n0."NomNiveau_0",
  n1."ID_Niveau_1",
  n1."NomNiveau_1",
  n2."ID_Niveau_2",
  n2."NomNiveau_2",
  n3."ID_Niveau_3",
  n3."NomNiveau_3",
  n4."ID_TypeNiveau_4_Fk",
  COALESCE(g_type4."AbrGenerique",' ') AS "Type_Niveau_4",
  n5."ID_TypeNiveau_5_Fk",
  COALESCE(g_type5."AbrGenerique",' ') AS "Type_Niveau_5",
  COUNT(DISTINCT n4."ID_Niveau_4") AS "Nb_Aires_Sante",
  COUNT(DISTINCT n5."ID_Niveau_5") AS "Nb_Structures_Sante"
FROM geolocalisation."T_Niveau_3" n3
JOIN geolocalisation."T_Niveau_2" n2
  ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
JOIN geolocalisation."T_Niveau_1" n1
  ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
JOIN geolocalisation."T_Niveau_0" n0
  ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
LEFT JOIN geolocalisation."T_Niveau_4" n4
  ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
LEFT JOIN geolocalisation."T_Niveau_5" n5
  ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
LEFT JOIN referentiel."T_Generique" g_type4
  ON n4."ID_TypeNiveau_4_Fk" = g_type4."ID_Generique"
LEFT JOIN referentiel."T_Generique" g_type5
  ON n5."ID_TypeNiveau_5_Fk" = g_type5."ID_Generique"
GROUP BY
  n0."ID_Niveau_0", n0."NomNiveau_0",
  n1."ID_Niveau_1", n1."NomNiveau_1",
  n2."ID_Niveau_2", n2."NomNiveau_2",
  n3."ID_Niveau_3", n3."NomNiveau_3",
  n4."ID_TypeNiveau_4_Fk", g_type4."AbrGenerique",
  n5."ID_TypeNiveau_5_Fk", g_type5."AbrGenerique";

ALTER TABLE geolocalisation."V_Stats_N3_Structures" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_Stats_N3_Structures" IS
'Vue d''indicateurs par Zone de Santé (Niveau 3) ET par type :
- nombre d''Aires de Santé (Niveau 4) par type
- nombre de structures/sites (Niveau 5) par type
avec le contexte hiérarchique complet (Niveaux 0 à 2).';

-- 3) Population des sites (N5) cumulée par ZS (N3) ET par type de structure
CREATE OR REPLACE VIEW geolocalisation."V_Pop_N3_Couverte_Sites" AS
SELECT
  n0."ID_Niveau_0",
  n0."NomNiveau_0",
  n1."ID_Niveau_1",
  n1."NomNiveau_1",
  n2."ID_Niveau_2",
  n2."NomNiveau_2",
  n3."ID_Niveau_3",
  n3."NomNiveau_3",
  n5."ID_TypeNiveau_5_Fk",
  COALESCE(g_type5."AbrGenerique",' ') AS "Type_Niveau_5",
  SUM(COALESCE(n5."PopulationNiveau_5",0)) AS "Pop_Cum_Sites"
FROM geolocalisation."T_Niveau_3" n3
JOIN geolocalisation."T_Niveau_2" n2
  ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
JOIN geolocalisation."T_Niveau_1" n1
  ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
JOIN geolocalisation."T_Niveau_0" n0
  ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
LEFT JOIN geolocalisation."T_Niveau_4" n4
  ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
LEFT JOIN geolocalisation."T_Niveau_5" n5
  ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
LEFT JOIN referentiel."T_Generique" g_type5
  ON n5."ID_TypeNiveau_5_Fk" = g_type5."ID_Generique"
GROUP BY
  n0."ID_Niveau_0", n0."NomNiveau_0",
  n1."ID_Niveau_1", n1."NomNiveau_1",
  n2."ID_Niveau_2", n2."NomNiveau_2",
  n3."ID_Niveau_3", n3."NomNiveau_3",
  n5."ID_TypeNiveau_5_Fk", g_type5."AbrGenerique";

ALTER TABLE geolocalisation."V_Pop_N3_Couverte_Sites" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_Pop_N3_Couverte_Sites" IS
'Vue d''indicateurs de population : somme des populations des sites (Niveau 5)
rattachés à chaque Zone de Santé (Niveau 3), ventilée par type de structure (Type_Niveau_5).';

-- 4) % d'aires de santé avec réseau par ZS (inchangé, mais toujours basé sur N4)
CREATE OR REPLACE VIEW geolocalisation."V_RESEAU_AS_par_ZS" AS
SELECT
  n0."ID_Niveau_0",
  n0."NomNiveau_0",
  n1."ID_Niveau_1",
  n1."NomNiveau_1",
  n2."ID_Niveau_2",
  n2."NomNiveau_2",
  n3."ID_Niveau_3",
  n3."NomNiveau_3",
  COUNT(*) AS "Nb_AS",
  SUM(
    CASE 
      WHEN g_reseau."AbrGenerique" IS NOT NULL 
           AND g_reseau."AbrGenerique" <> 'Sans réseau'
      THEN 1 ELSE 0 
    END
  ) AS "Nb_AS_Avec_Reseau",
  ROUND(
    100.0 * SUM(
      CASE 
        WHEN g_reseau."AbrGenerique" IS NOT NULL 
             AND g_reseau."AbrGenerique" <> 'Sans réseau'
        THEN 1 ELSE 0 
      END
    ) / NULLIF(COUNT(*),0)
  , 1) AS "Pct_AS_Avec_Reseau"
FROM geolocalisation."T_Niveau_3" n3
JOIN geolocalisation."T_Niveau_2" n2
  ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
JOIN geolocalisation."T_Niveau_1" n1
  ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
JOIN geolocalisation."T_Niveau_0" n0
  ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
JOIN geolocalisation."T_Niveau_4" n4
  ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
LEFT JOIN referentiel."T_Generique" g_reseau
  ON n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique"
GROUP BY
  n0."ID_Niveau_0", n0."NomNiveau_0",
  n1."ID_Niveau_1", n1."NomNiveau_1",
  n2."ID_Niveau_2", n2."NomNiveau_2",
  n3."ID_Niveau_3", n3."NomNiveau_3";

ALTER TABLE geolocalisation."V_RESEAU_AS_par_ZS" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_RESEAU_AS_par_ZS" IS
'Vue d''indicateurs de connectivité : nombre et pourcentage d''Aires de Santé (Niveau 4)
disposant de réseau pour chaque Zone de Santé (Niveau 3).';

-- 5) ZS sans aucune aire de santé (N4)
CREATE OR REPLACE VIEW geolocalisation."V_ZS_sans_AS" AS
SELECT
  n0."ID_Niveau_0",
  n0."NomNiveau_0",
  n1."ID_Niveau_1",
  n1."NomNiveau_1",
  n2."ID_Niveau_2",
  n2."NomNiveau_2",
  n3."ID_Niveau_3",
  n3."NomNiveau_3"
FROM geolocalisation."T_Niveau_3" n3
JOIN geolocalisation."T_Niveau_2" n2
  ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
JOIN geolocalisation."T_Niveau_1" n1
  ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
JOIN geolocalisation."T_Niveau_0" n0
  ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
LEFT JOIN geolocalisation."T_Niveau_4" n4
  ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
GROUP BY
  n0."ID_Niveau_0", n0."NomNiveau_0",
  n1."ID_Niveau_1", n1."NomNiveau_1",
  n2."ID_Niveau_2", n2."NomNiveau_2",
  n3."ID_Niveau_3", n3."NomNiveau_3"
HAVING COUNT(n4."ID_Niveau_4") = 0;

ALTER TABLE geolocalisation."V_ZS_sans_AS" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_ZS_sans_AS" IS
'Vue de contrôle de qualité : liste des Zones de Santé (Niveau 3) ne possédant aucune Aire de Santé (Niveau 4) associée.';

-- 6) Aires de santé sans site (N5)
CREATE OR REPLACE VIEW geolocalisation."V_AS_sans_Site" AS
SELECT
  n0."ID_Niveau_0",
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
JOIN geolocalisation."T_Niveau_3" n3
  ON n4."ID_Niveau_3_Fk" = n3."ID_Niveau_3"
JOIN geolocalisation."T_Niveau_2" n2
  ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
JOIN geolocalisation."T_Niveau_1" n1
  ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
JOIN geolocalisation."T_Niveau_0" n0
  ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
LEFT JOIN geolocalisation."T_Niveau_5" n5
  ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
GROUP BY
  n0."ID_Niveau_0", n0."NomNiveau_0",
  n1."ID_Niveau_1", n1."NomNiveau_1",
  n2."ID_Niveau_2", n2."NomNiveau_2",
  n3."ID_Niveau_3", n3."NomNiveau_3",
  n4."ID_Niveau_4", n4."NomNiveau_4"
HAVING COUNT(n5."ID_Niveau_5") = 0;

ALTER TABLE geolocalisation."V_AS_sans_Site" OWNER TO postgres;

COMMENT ON VIEW geolocalisation."V_AS_sans_Site" IS
'Vue de contrôle de qualité : liste des Aires de Santé (Niveau 4) sans aucune structure/site (Niveau 5) associé.';

COMMIT;
