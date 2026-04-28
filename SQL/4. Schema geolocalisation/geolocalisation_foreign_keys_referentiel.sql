BEGIN;
-- Ce script ajoute les cles etrangeres manquantes entre geolocalisation et referentiel.T_Generique.
-- Les contraintes sont creees en NOT VALID pour permettre une mise en place progressive
-- meme si des donnees historiques doivent encore etre nettoyees.
-- Une fois les donnees corrigees, vous pouvez lancer les ALTER TABLE ... VALIDATE CONSTRAINT
-- proposes en fin de script.
-- Index utiles pour les futures validations et pour les jointures applicatives.
CREATE INDEX IF NOT EXISTS "idx_n2_id_typeniveau2_fk_ref" ON geolocalisation."T_Niveau_2"("ID_TypeNiveau_2_Fk");
CREATE INDEX IF NOT EXISTS "idx_n2_id_statutniveau2_fk_ref" ON geolocalisation."T_Niveau_2"("ID_StatutNiveau_2");
CREATE INDEX IF NOT EXISTS "idx_n2_id_statusdeploi_fk_ref" ON geolocalisation."T_Niveau_2"("ID_StatusDeploiFk");
CREATE INDEX IF NOT EXISTS "idx_n2_id_voieaccesdpsant_fk_ref" ON geolocalisation."T_Niveau_2"("ID_VoieAccesDPSANTFk");
CREATE INDEX IF NOT EXISTS "idx_n3_id_typeniveau2_fk_ref" ON geolocalisation."T_Niveau_3"("ID_TypeNiveau_2_Fk");
CREATE INDEX IF NOT EXISTS "idx_n3_id_statutniveau3_fk_ref" ON geolocalisation."T_Niveau_3"("ID_StatutNiveau_3_Fk");
CREATE INDEX IF NOT EXISTS "idx_n3_id_statutdeploie_fk_ref" ON geolocalisation."T_Niveau_3"("ID_StatutDeploieFk");
CREATE INDEX IF NOT EXISTS "idx_n3_id_voieaccesantbcz_fk_ref" ON geolocalisation."T_Niveau_3"("ID_VoieAccesANTBCZFk");
CREATE INDEX IF NOT EXISTS "idx_n3_id_voieaccesdpsbcz_fk_ref" ON geolocalisation."T_Niveau_3"("ID_VoieAccesDPSBCZFk");
CREATE INDEX IF NOT EXISTS "idx_n4_id_typeniveau4_fk_ref" ON geolocalisation."T_Niveau_4"("ID_TypeNiveau_4_Fk");
CREATE INDEX IF NOT EXISTS "idx_n4_id_disporeseau_fk_ref" ON geolocalisation."T_Niveau_4"("ID_DispoReseauNiveau_4");
CREATE INDEX IF NOT EXISTS "idx_n4_id_voieacceszsa_fk_ref" ON geolocalisation."T_Niveau_4"("ID_VoieAccesZsASFk");
CREATE INDEX IF NOT EXISTS "idx_n4_id_statutniveau4_fk_ref" ON geolocalisation."T_Niveau_4"("ID_StatutNiveau_4");
CREATE INDEX IF NOT EXISTS "idx_n4_id_statutdeploiement_fk_ref" ON geolocalisation."T_Niveau_4"("ID_StatutDeploiementFk");
CREATE INDEX IF NOT EXISTS "idx_n5_id_typeniveau5_fk_ref" ON geolocalisation."T_Niveau_5"("ID_TypeNiveau_5_Fk");
CREATE INDEX IF NOT EXISTS "idx_n5_id_disporeseau_fk_ref" ON geolocalisation."T_Niveau_5"("ID_DispoReseauNiveau_5");
CREATE INDEX IF NOT EXISTS "idx_n5_id_voieaccessite_fk_ref" ON geolocalisation."T_Niveau_5"("ID_VoieAccesZsSiteFk");
CREATE INDEX IF NOT EXISTS "idx_n5_id_statutniveau5_fk_ref" ON geolocalisation."T_Niveau_5"("ID_StatutNiveau_5");
CREATE INDEX IF NOT EXISTS "idx_n5_id_statutdeploiement_fk_ref" ON geolocalisation."T_Niveau_5"("ID_StatutDeploiementFk");
CREATE INDEX IF NOT EXISTS "idx_n5_id_typetoit_fk_ref" ON geolocalisation."T_Niveau_5"("ID_TypeToitFk");
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_StatutNiveau_2'
        AND conrelid = 'geolocalisation."T_Niveau_2"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_2"
ADD CONSTRAINT "Fk_ID_StatutNiveau_2" FOREIGN KEY ("ID_StatutNiveau_2") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_StatusDeploiFk'
        AND conrelid = 'geolocalisation."T_Niveau_2"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_2"
ADD CONSTRAINT "Fk_ID_StatusDeploiFk" FOREIGN KEY ("ID_StatusDeploiFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_VoieAccesDPSANTFk'
        AND conrelid = 'geolocalisation."T_Niveau_2"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_2"
ADD CONSTRAINT "Fk_ID_VoieAccesDPSANTFk" FOREIGN KEY ("ID_VoieAccesDPSANTFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_StatutNiveau_3'
        AND conrelid = 'geolocalisation."T_Niveau_3"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_3"
ADD CONSTRAINT "Fk_ID_StatutNiveau_3" FOREIGN KEY ("ID_StatutNiveau_3_Fk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_StatutDeploieFk'
        AND conrelid = 'geolocalisation."T_Niveau_3"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_3"
ADD CONSTRAINT "Fk_ID_StatutDeploieFk" FOREIGN KEY ("ID_StatutDeploieFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_VoieAccesANTBCZFk'
        AND conrelid = 'geolocalisation."T_Niveau_3"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_3"
ADD CONSTRAINT "Fk_ID_VoieAccesANTBCZFk" FOREIGN KEY ("ID_VoieAccesANTBCZFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_VoieAccesDPSBCZFk'
        AND conrelid = 'geolocalisation."T_Niveau_3"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_3"
ADD CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk" FOREIGN KEY ("ID_VoieAccesDPSBCZFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_DispoReseauNiveau_4'
        AND conrelid = 'geolocalisation."T_Niveau_4"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_4"
ADD CONSTRAINT "Fk_ID_DispoReseauNiveau_4" FOREIGN KEY ("ID_DispoReseauNiveau_4") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_VoieAccesZsASFk'
        AND conrelid = 'geolocalisation."T_Niveau_4"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_4"
ADD CONSTRAINT "Fk_ID_VoieAccesZsASFk" FOREIGN KEY ("ID_VoieAccesZsASFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_StatutNiveau_4'
        AND conrelid = 'geolocalisation."T_Niveau_4"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_4"
ADD CONSTRAINT "Fk_ID_StatutNiveau_4" FOREIGN KEY ("ID_StatutNiveau_4") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_StatutDeploiementNiveau_4'
        AND conrelid = 'geolocalisation."T_Niveau_4"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_4"
ADD CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4" FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_DispoReseauNiveau_5'
        AND conrelid = 'geolocalisation."T_Niveau_5"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_5"
ADD CONSTRAINT "Fk_ID_DispoReseauNiveau_5" FOREIGN KEY ("ID_DispoReseauNiveau_5") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_VoieAccesZsSiteFk'
        AND conrelid = 'geolocalisation."T_Niveau_5"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_5"
ADD CONSTRAINT "Fk_ID_VoieAccesZsSiteFk" FOREIGN KEY ("ID_VoieAccesZsSiteFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_StatutNiveau_5'
        AND conrelid = 'geolocalisation."T_Niveau_5"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_5"
ADD CONSTRAINT "Fk_ID_StatutNiveau_5" FOREIGN KEY ("ID_StatutNiveau_5") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_StatutDeploiementNiveau_5'
        AND conrelid = 'geolocalisation."T_Niveau_5"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_5"
ADD CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5" FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Fk_ID_TypeToitFk'
        AND conrelid = 'geolocalisation."T_Niveau_5"'::regclass
) THEN
ALTER TABLE geolocalisation."T_Niveau_5"
ADD CONSTRAINT "Fk_ID_TypeToitFk" FOREIGN KEY ("ID_TypeToitFk") REFERENCES referentiel."T_Generique" ("ID_Generique") ON UPDATE CASCADE ON DELETE NO ACTION NOT VALID;
END IF;
END $$;
COMMIT;
-- Une fois les references orphelines corrigees, validez progressivement les contraintes.
-- ALTER TABLE geolocalisation."T_Niveau_2" VALIDATE CONSTRAINT "Fk_ID_StatutNiveau_2";
-- ALTER TABLE geolocalisation."T_Niveau_2" VALIDATE CONSTRAINT "Fk_ID_StatusDeploiFk";
-- ALTER TABLE geolocalisation."T_Niveau_2" VALIDATE CONSTRAINT "Fk_ID_VoieAccesDPSANTFk";
-- ALTER TABLE geolocalisation."T_Niveau_3" VALIDATE CONSTRAINT "Fk_ID_StatutNiveau_3";
-- ALTER TABLE geolocalisation."T_Niveau_3" VALIDATE CONSTRAINT "Fk_ID_StatutDeploieFk";
-- ALTER TABLE geolocalisation."T_Niveau_3" VALIDATE CONSTRAINT "Fk_ID_VoieAccesANTBCZFk";
-- ALTER TABLE geolocalisation."T_Niveau_3" VALIDATE CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk";
-- ALTER TABLE geolocalisation."T_Niveau_4" VALIDATE CONSTRAINT "Fk_ID_DispoReseauNiveau_4";
-- ALTER TABLE geolocalisation."T_Niveau_4" VALIDATE CONSTRAINT "Fk_ID_VoieAccesZsASFk";
-- ALTER TABLE geolocalisation."T_Niveau_4" VALIDATE CONSTRAINT "Fk_ID_StatutNiveau_4";
-- ALTER TABLE geolocalisation."T_Niveau_4" VALIDATE CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4";
-- ALTER TABLE geolocalisation."T_Niveau_5" VALIDATE CONSTRAINT "Fk_ID_DispoReseauNiveau_5";
-- ALTER TABLE geolocalisation."T_Niveau_5" VALIDATE CONSTRAINT "Fk_ID_VoieAccesZsSiteFk";
-- ALTER TABLE geolocalisation."T_Niveau_5" VALIDATE CONSTRAINT "Fk_ID_StatutNiveau_5";
-- ALTER TABLE geolocalisation."T_Niveau_5" VALIDATE CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5";
-- ALTER TABLE geolocalisation."T_Niveau_5" VALIDATE CONSTRAINT "Fk_ID_TypeToitFk";