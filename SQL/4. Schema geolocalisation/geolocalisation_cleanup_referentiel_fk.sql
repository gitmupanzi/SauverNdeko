BEGIN;

-- Ce script neutralise en douceur les references orphelines de geolocalisation
-- vers referentiel.T_Generique en les remplacant par NULL.
-- Il est pense pour etre execute avant la validation definitive des contraintes FK.
-- A relire avant execution si certaines colonnes doivent plutot etre corrigees
-- vers une valeur metier precise plutot qu'effacees.

UPDATE geolocalisation."T_Niveau_2" n
SET "ID_StatutNiveau_2" = NULL
WHERE n."ID_StatutNiveau_2" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_StatutNiveau_2"
  );

UPDATE geolocalisation."T_Niveau_2" n
SET "ID_StatusDeploiFk" = NULL
WHERE n."ID_StatusDeploiFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_StatusDeploiFk"
  );

UPDATE geolocalisation."T_Niveau_2" n
SET "ID_VoieAccesDPSANTFk" = NULL
WHERE n."ID_VoieAccesDPSANTFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_VoieAccesDPSANTFk"
  );

UPDATE geolocalisation."T_Niveau_3" n
SET "ID_StatutNiveau_3_Fk" = NULL
WHERE n."ID_StatutNiveau_3_Fk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_StatutNiveau_3_Fk"
  );

UPDATE geolocalisation."T_Niveau_3" n
SET "ID_StatutDeploieFk" = NULL
WHERE n."ID_StatutDeploieFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_StatutDeploieFk"
  );

UPDATE geolocalisation."T_Niveau_3" n
SET "ID_VoieAccesANTBCZFk" = NULL
WHERE n."ID_VoieAccesANTBCZFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_VoieAccesANTBCZFk"
  );

UPDATE geolocalisation."T_Niveau_3" n
SET "ID_VoieAccesDPSBCZFk" = NULL
WHERE n."ID_VoieAccesDPSBCZFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_VoieAccesDPSBCZFk"
  );

UPDATE geolocalisation."T_Niveau_4" n
SET "ID_DispoReseauNiveau_4" = NULL
WHERE n."ID_DispoReseauNiveau_4" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_DispoReseauNiveau_4"
  );

UPDATE geolocalisation."T_Niveau_4" n
SET "ID_VoieAccesZsASFk" = NULL
WHERE n."ID_VoieAccesZsASFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_VoieAccesZsASFk"
  );

UPDATE geolocalisation."T_Niveau_4" n
SET "ID_StatutNiveau_4" = NULL
WHERE n."ID_StatutNiveau_4" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_StatutNiveau_4"
  );

UPDATE geolocalisation."T_Niveau_4" n
SET "ID_StatutDeploiementFk" = NULL
WHERE n."ID_StatutDeploiementFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_StatutDeploiementFk"
  );

UPDATE geolocalisation."T_Niveau_5" n
SET "ID_DispoReseauNiveau_5" = NULL
WHERE n."ID_DispoReseauNiveau_5" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_DispoReseauNiveau_5"
  );

UPDATE geolocalisation."T_Niveau_5" n
SET "ID_VoieAccesZsSiteFk" = NULL
WHERE n."ID_VoieAccesZsSiteFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_VoieAccesZsSiteFk"
  );

UPDATE geolocalisation."T_Niveau_5" n
SET "ID_StatutNiveau_5" = NULL
WHERE n."ID_StatutNiveau_5" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_StatutNiveau_5"
  );

UPDATE geolocalisation."T_Niveau_5" n
SET "ID_StatutDeploiementFk" = NULL
WHERE n."ID_StatutDeploiementFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_StatutDeploiementFk"
  );

UPDATE geolocalisation."T_Niveau_5" n
SET "ID_TypeToitFk" = NULL
WHERE n."ID_TypeToitFk" IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM referentiel."T_Generique" g
      WHERE g."ID_Generique" = n."ID_TypeToitFk"
  );

COMMIT;

-- Verification rapide post-nettoyage:
-- Relancez ensuite SQL/4. Schema geolocalisation/Test_geolocalisation.sql
-- pour confirmer que tous les compteurs d'orphelins sont revenus a zero.
