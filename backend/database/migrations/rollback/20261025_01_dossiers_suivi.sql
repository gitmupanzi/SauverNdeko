-- Retrait du socle uniquement si aucune donnée de classement n’a été créée.
BEGIN;
SET LOCAL lock_timeout='3s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM logistique."T_DossierSuivi") OR EXISTS(SELECT 1 FROM logistique."T_CategorieDossierSuivi") OR EXISTS(SELECT 1 FROM logistique."T_DossierSuiviMembre") THEN RAISE EXCEPTION 'Retrait refusé : des données de classement existent.'; END IF;
END $$;
DROP VIEW logistique."V_DossierSuiviMembre";
DROP VIEW logistique."V_DossierSuivi";
DROP VIEW logistique."V_CategorieDossierSuivi";
DROP TABLE logistique."T_DossierSuiviMembre";
DROP TABLE logistique."T_DossierSuivi";
DROP TABLE logistique."T_CategorieDossierSuivi";
DROP FUNCTION logistique.verifier_dossier_suivi();
COMMIT;
