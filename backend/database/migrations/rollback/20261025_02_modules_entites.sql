-- Retrait uniquement si les rattachements de reprise n’ont pas été modifiés et qu’aucune règle de rôle n’a été créée.
BEGIN;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM systeme."T_LicenceModule" WHERE "Origine"<>'reprise' OR "Version"<>1 OR "ModifieParUserFk" IS NOT NULL) OR EXISTS(SELECT 1 FROM systeme."T_RoleModule") THEN RAISE EXCEPTION 'Retrait refusé : la configuration a été utilisée.'; END IF;
END $$;
DROP VIEW systeme."V_EntiteModuleActif";
DROP VIEW systeme."V_RoleModule";
DROP VIEW systeme."V_LicenceModule";
DROP TABLE systeme."T_RoleModule";
DROP TABLE systeme."T_LicenceModule";
DROP TABLE systeme."T_ModuleApplication";
DROP FUNCTION systeme.verifier_activation_module();
COMMIT;
