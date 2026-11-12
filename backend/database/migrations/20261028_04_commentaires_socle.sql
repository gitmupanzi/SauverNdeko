-- Complète les commentaires des contraintes NOT NULL implicites PostgreSQL18.
-- Aucune donnée, préférence ni règle métier n'est modifiée.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='30s';
SET LOCAL search_path=pg_catalog;
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base hors perimetre';END IF;
 IF to_regclass('referentiel."T_InterfaceTableau"') IS NULL OR to_regclass('referentiel."T_PreferenceTableau"') IS NULL THEN RAISE EXCEPTION 'Migration 20261028_02 requise';END IF;
END $$;
COMMENT ON CONSTRAINT "T_InterfaceTableau_CleInterface_not_null" ON referentiel."T_InterfaceTableau" IS 'Chaque catalogue possède un identifiant stable d’interface renseigné.';
COMMENT ON CONSTRAINT "T_InterfaceTableau_Module_not_null" ON referentiel."T_InterfaceTableau" IS 'Le module propriétaire du catalogue doit être renseigné pour vérifier les droits.';
COMMENT ON CONSTRAINT "T_InterfaceTableau_Version_not_null" ON referentiel."T_InterfaceTableau" IS 'La version de référence du catalogue est toujours connue.';
COMMENT ON CONSTRAINT "T_InterfaceTableau_Colonnes_not_null" ON referentiel."T_InterfaceTableau" IS 'La définition ordonnée des colonnes ne peut être absente.';
COMMENT ON CONSTRAINT "T_InterfaceTableau_Actif_not_null" ON referentiel."T_InterfaceTableau" IS 'La disponibilité du catalogue doit être définie explicitement.';
COMMENT ON CONSTRAINT "T_InterfaceTableau_ModifieLe_not_null" ON referentiel."T_InterfaceTableau" IS 'La date technique de mise à jour du catalogue reste renseignée.';
COMMENT ON CONSTRAINT "T_PreferenceTableau_ID_PreferenceTableau_not_null" ON referentiel."T_PreferenceTableau" IS 'Toute préférence possède son identifiant technique généré.';
COMMENT ON CONSTRAINT "T_PreferenceTableau_CleInterfaceFk_not_null" ON referentiel."T_PreferenceTableau" IS 'La préférence référence nécessairement une interface existante.';
COMMENT ON CONSTRAINT "T_PreferenceTableau_IdUserFk_not_null" ON referentiel."T_PreferenceTableau" IS 'Le propriétaire personnel de la préférence reste obligatoire.';
COMMENT ON CONSTRAINT "T_PreferenceTableau_Usage_not_null" ON referentiel."T_PreferenceTableau" IS 'L’usage tableau ou export est toujours précisé pour préserver leur indépendance.';
COMMENT ON CONSTRAINT "T_PreferenceTableau_Colonnes_not_null" ON referentiel."T_PreferenceTableau" IS 'La liste ordonnée des colonnes choisies reste renseignée.';
COMMENT ON CONSTRAINT "T_PreferenceTableau_Version_not_null" ON referentiel."T_PreferenceTableau" IS 'Une révision persistée est nécessaire pour contrôler les modifications concurrentes.';
COMMENT ON CONSTRAINT "T_PreferenceTableau_ModifieLe_not_null" ON referentiel."T_PreferenceTableau" IS 'La date technique de dernière modification de la préférence est obligatoire.';
COMMIT;
