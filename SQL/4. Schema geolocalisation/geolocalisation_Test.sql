-- Ordre conseille:
-- 1. Executer geolocalisation_cleanup_referentiel_fk.sql si vous voulez neutraliser les references orphelines
-- 2. Executer geolocalisation_foreign_keys_referentiel.sql pour ajouter les FK en NOT VALID
-- 3. Lancer ce script de test
-- 4. Quand tous les compteurs d'orphelins sont a zero, executer geolocalisation_validate_referentiel_fk.sql

-- Verification rapide des tables source
SELECT * FROM geolocalisation."T_Niveau_0" LIMIT 20;
SELECT * FROM geolocalisation."T_Niveau_1_Old" LIMIT 20;
SELECT * FROM geolocalisation."T_Niveau_1" LIMIT 20;
SELECT * FROM geolocalisation."T_Niveau_2" LIMIT 20;
SELECT * FROM geolocalisation."T_Niveau_3" LIMIT 20;
SELECT * FROM geolocalisation."T_Niveau_4" LIMIT 20;
SELECT * FROM geolocalisation."T_Niveau_5" LIMIT 20;

-- Verification rapide des vues de reference
SELECT * FROM geolocalisation."V_Niveau_0" LIMIT 20;
SELECT * FROM geolocalisation."V_Niveau_1_Old" LIMIT 20;
SELECT * FROM geolocalisation."V_Niveau_1" LIMIT 20;
SELECT * FROM geolocalisation."V_Niveau_2" LIMIT 20;
SELECT * FROM geolocalisation."V_Niveau_3" LIMIT 20;
SELECT * FROM geolocalisation."V_Niveau_4" LIMIT 20;
SELECT * FROM geolocalisation."V_Niveau_5" LIMIT 20;

-- Verification rapide des vues de controle et d'indicateurs
SELECT * FROM geolocalisation."V_AS_sans_Site" LIMIT 20;
SELECT * FROM geolocalisation."V_ZS_sans_AS" LIMIT 20;
SELECT * FROM geolocalisation."V_Pop_N3_Couverte_Sites" LIMIT 20;
SELECT * FROM geolocalisation."V_RESEAU_AS_par_ZS" LIMIT 20;
SELECT * FROM geolocalisation."V_Stats_N1_N2" LIMIT 20;
SELECT * FROM geolocalisation."V_Stats_N3_Structures" LIMIT 20;

-- Verifications ciblees pour le CRUD
SELECT "ID_Niveau_4", "NomNiveau_4", "ID_Niveau_3_Fk"
FROM geolocalisation."V_Niveau_4"
LIMIT 20;

SELECT "ID_Niveau_5", "NomNiveau_5", "ID_Niveau_4_Fk", "ID_Niveau_3_Fk"
FROM geolocalisation."V_Niveau_5"
LIMIT 20;

-- Verifications des references geolocalisation -> referentiel avant validation des FK
SELECT 'T_Niveau_2.ID_StatutNiveau_2' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_2" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_StatutNiveau_2" = g."ID_Generique"
WHERE n."ID_StatutNiveau_2" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_2.ID_StatusDeploiFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_2" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_StatusDeploiFk" = g."ID_Generique"
WHERE n."ID_StatusDeploiFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_2.ID_VoieAccesDPSANTFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_2" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_VoieAccesDPSANTFk" = g."ID_Generique"
WHERE n."ID_VoieAccesDPSANTFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_3.ID_StatutNiveau_3_Fk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_3" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_StatutNiveau_3_Fk" = g."ID_Generique"
WHERE n."ID_StatutNiveau_3_Fk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_3.ID_StatutDeploieFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_3" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_StatutDeploieFk" = g."ID_Generique"
WHERE n."ID_StatutDeploieFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_3.ID_VoieAccesANTBCZFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_3" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_VoieAccesANTBCZFk" = g."ID_Generique"
WHERE n."ID_VoieAccesANTBCZFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_3.ID_VoieAccesDPSBCZFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_3" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_VoieAccesDPSBCZFk" = g."ID_Generique"
WHERE n."ID_VoieAccesDPSBCZFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_4.ID_DispoReseauNiveau_4' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_4" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_DispoReseauNiveau_4" = g."ID_Generique"
WHERE n."ID_DispoReseauNiveau_4" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_4.ID_VoieAccesZsASFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_4" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_VoieAccesZsASFk" = g."ID_Generique"
WHERE n."ID_VoieAccesZsASFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_4.ID_StatutNiveau_4' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_4" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_StatutNiveau_4" = g."ID_Generique"
WHERE n."ID_StatutNiveau_4" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_4.ID_StatutDeploiementFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_4" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_StatutDeploiementFk" = g."ID_Generique"
WHERE n."ID_StatutDeploiementFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_5.ID_DispoReseauNiveau_5' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_5" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_DispoReseauNiveau_5" = g."ID_Generique"
WHERE n."ID_DispoReseauNiveau_5" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_5.ID_VoieAccesZsSiteFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_5" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_VoieAccesZsSiteFk" = g."ID_Generique"
WHERE n."ID_VoieAccesZsSiteFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_5.ID_StatutNiveau_5' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_5" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_StatutNiveau_5" = g."ID_Generique"
WHERE n."ID_StatutNiveau_5" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_5.ID_StatutDeploiementFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_5" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_StatutDeploiementFk" = g."ID_Generique"
WHERE n."ID_StatutDeploiementFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;

SELECT 'T_Niveau_5.ID_TypeToitFk' AS controle, count(*) AS nb_orphelins
FROM geolocalisation."T_Niveau_5" n
LEFT JOIN referentiel."T_Generique" g ON n."ID_TypeToitFk" = g."ID_Generique"
WHERE n."ID_TypeToitFk" IS NOT NULL
  AND g."ID_Generique" IS NULL;
