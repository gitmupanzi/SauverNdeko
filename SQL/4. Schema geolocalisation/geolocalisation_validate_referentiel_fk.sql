BEGIN;

-- A executer seulement apres :
-- 1. geolocalisation_cleanup_referentiel_fk.sql
-- 2. geolocalisation_foreign_keys_referentiel.sql
-- 3. Test_geolocalisation.sql avec tous les compteurs d'orphelins a zero

ALTER TABLE geolocalisation."T_Niveau_2"
    VALIDATE CONSTRAINT "Fk_ID_StatutNiveau_2";

ALTER TABLE geolocalisation."T_Niveau_2"
    VALIDATE CONSTRAINT "Fk_ID_StatusDeploiFk";

ALTER TABLE geolocalisation."T_Niveau_2"
    VALIDATE CONSTRAINT "Fk_ID_VoieAccesDPSANTFk";

ALTER TABLE geolocalisation."T_Niveau_3"
    VALIDATE CONSTRAINT "Fk_ID_StatutNiveau_3";

ALTER TABLE geolocalisation."T_Niveau_3"
    VALIDATE CONSTRAINT "Fk_ID_StatutDeploieFk";

ALTER TABLE geolocalisation."T_Niveau_3"
    VALIDATE CONSTRAINT "Fk_ID_VoieAccesANTBCZFk";

ALTER TABLE geolocalisation."T_Niveau_3"
    VALIDATE CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk";

ALTER TABLE geolocalisation."T_Niveau_4"
    VALIDATE CONSTRAINT "Fk_ID_DispoReseauNiveau_4";

ALTER TABLE geolocalisation."T_Niveau_4"
    VALIDATE CONSTRAINT "Fk_ID_VoieAccesZsASFk";

ALTER TABLE geolocalisation."T_Niveau_4"
    VALIDATE CONSTRAINT "Fk_ID_StatutNiveau_4";

ALTER TABLE geolocalisation."T_Niveau_4"
    VALIDATE CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4";

ALTER TABLE geolocalisation."T_Niveau_5"
    VALIDATE CONSTRAINT "Fk_ID_DispoReseauNiveau_5";

ALTER TABLE geolocalisation."T_Niveau_5"
    VALIDATE CONSTRAINT "Fk_ID_VoieAccesZsSiteFk";

ALTER TABLE geolocalisation."T_Niveau_5"
    VALIDATE CONSTRAINT "Fk_ID_StatutNiveau_5";

ALTER TABLE geolocalisation."T_Niveau_5"
    VALIDATE CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5";

ALTER TABLE geolocalisation."T_Niveau_5"
    VALIDATE CONSTRAINT "Fk_ID_TypeToitFk";

COMMIT;
