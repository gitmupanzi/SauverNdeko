-- Métadonnée omise lors de l'extension du catalogue des interfaces au module Caisse.
-- Aucun changement de définition de contrainte ni de donnée.
BEGIN;
COMMENT ON CONSTRAINT ck_interface_tableau_module ON referentiel."T_InterfaceTableau"
 IS 'Modules autorisés pour les tableaux et exports : Logistique, Référentiels, Administration, Territoires, Support et Caisse. La liste ne définit aucun droit ni abonnement.';
COMMIT;
