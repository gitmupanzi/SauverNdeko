-- Les bons d’écart et leurs compensations sont des documents internes, sans flux commercial.
-- Prérequis : inventaires 20261026_03. Aucun document ni mouvement historique n’est modifié.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='60s';
DO $preflight$
BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base hors périmètre';END IF;
 IF to_regprocedure('logistique.fn_bon_inventaire(integer)') IS NOT NULL THEN RAISE EXCEPTION 'Garde inventaire08 déjà installée';END IF;
 IF NOT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='logistique' AND table_name='T_InventaireLigne' AND column_name='ID_CommandeAnnulationFk') THEN RAISE EXCEPTION 'Annulation inventaire03 requise';END IF;
END $preflight$;
LOCK TABLE logistique."T_InventaireLigne",logistique."T_Facture",logistique."T_RetourBon",logistique."T_Commande" IN SHARE ROW EXCLUSIVE MODE;
DO $existing$
BEGIN
 IF EXISTS(SELECT FROM logistique."T_InventaireLigne" l JOIN logistique."T_Commande" c ON c."ID_Commande" IN(l."ID_CommandeCorrectionFk",l."ID_CommandeAnnulationFk") WHERE NULLIF(btrim(c."CodeFacture"),'') IS NOT NULL OR EXISTS(SELECT FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=c."ID_Commande") OR EXISTS(SELECT FROM logistique."T_RetourBon" r WHERE c."ID_Commande" IN(r."ID_CommandeOrigineFk",r."ID_CommandeRetourFk"))) THEN
  RAISE EXCEPTION 'Des bons d’inventaire possèdent déjà une facture ou un retour : examiner l’historique avant migration, sans le réécrire.' USING ERRCODE='23514';
 END IF;
END $existing$;
CREATE INDEX IF NOT EXISTS ix_inventaire_ligne_bon_correction ON logistique."T_InventaireLigne"("ID_CommandeCorrectionFk") WHERE "ID_CommandeCorrectionFk" IS NOT NULL;
CREATE VIEW logistique."V_BonInventaire" AS
 SELECT DISTINCT "ID_CommandeCorrectionFk" AS "ID_Commande","ID_InventaireFk" AS "ID_Inventaire",'correction'::text AS "RoleBon" FROM logistique."T_InventaireLigne" WHERE "ID_CommandeCorrectionFk" IS NOT NULL
 UNION
 SELECT DISTINCT "ID_CommandeAnnulationFk","ID_InventaireFk",'annulation'::text FROM logistique."T_InventaireLigne" WHERE "ID_CommandeAnnulationFk" IS NOT NULL;
CREATE FUNCTION logistique.fn_bon_inventaire(p_commande integer) RETURNS boolean LANGUAGE sql VOLATILE PARALLEL UNSAFE SET search_path=pg_catalog
 AS $$ SELECT EXISTS(SELECT FROM logistique."V_BonInventaire" WHERE "ID_Commande"=p_commande) $$;
CREATE FUNCTION logistique.verifier_bon_inventaire_non_commercial() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $guard$
DECLARE targets integer[];identifier integer;
BEGIN
 IF TG_TABLE_NAME='T_Facture' THEN targets=ARRAY[NEW."ID_CommandeFk"];
 ELSIF TG_TABLE_NAME='T_RetourBon' THEN targets=ARRAY[NEW."ID_CommandeOrigineFk",NEW."ID_CommandeRetourFk"];
 ELSIF TG_TABLE_NAME='T_Commande' THEN
  IF NEW."CodeFacture" IS NOT DISTINCT FROM OLD."CodeFacture" OR NULLIF(btrim(NEW."CodeFacture"),'') IS NULL THEN RETURN NEW;END IF;
  targets=ARRAY[NEW."ID_Commande"];
 ELSE targets=ARRAY[NEW."ID_CommandeCorrectionFk",NEW."ID_CommandeAnnulationFk",OLD."ID_CommandeCorrectionFk",OLD."ID_CommandeAnnulationFk"];
 END IF;
 -- Un verrou commun aux deux sens empêche facture et rattachement concurrents.
 PERFORM 1 FROM logistique."T_Commande" c WHERE c."ID_Commande"=ANY(targets) ORDER BY c."ID_Commande" FOR UPDATE;
 IF TG_TABLE_NAME IN('T_Facture','T_RetourBon','T_Commande') THEN
  FOREACH identifier IN ARRAY targets LOOP
   IF logistique.fn_bon_inventaire(identifier) THEN RAISE EXCEPTION 'Un bon d’inventaire ne peut pas être facturé ou restitué comme une opération commerciale.' USING ERRCODE='23514',CONSTRAINT='inventaire_bon_non_commercial';END IF;
  END LOOP;
 ELSE
  FOREACH identifier IN ARRAY targets LOOP
   IF identifier IS NOT NULL AND (
     EXISTS(SELECT FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=identifier)
     OR EXISTS(SELECT FROM logistique."T_RetourBon" r WHERE identifier IN(r."ID_CommandeOrigineFk",r."ID_CommandeRetourFk"))
     OR EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."ID_Commande"=identifier AND NULLIF(btrim(c."CodeFacture"),'') IS NOT NULL))
   THEN RAISE EXCEPTION 'Un bon commercial ne peut pas servir de correction ou d’annulation d’inventaire.' USING ERRCODE='23514',CONSTRAINT='inventaire_bon_non_commercial';END IF;
  END LOOP;
 END IF;
 IF TG_WHEN='AFTER' THEN RETURN NULL;ELSIF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;
END $guard$;
CREATE TRIGGER aa_08_facture_inventaire_non_commercial BEFORE INSERT ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();
CREATE TRIGGER aa_08_retour_inventaire_non_commercial BEFORE INSERT ON logistique."T_RetourBon" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();
CREATE TRIGGER aa_08_code_facture_inventaire BEFORE UPDATE OF "CodeFacture" ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();
CREATE TRIGGER aa_08_ligne_inventaire_non_commercial BEFORE INSERT OR UPDATE ON logistique."T_InventaireLigne" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();
CREATE CONSTRAINT TRIGGER inventaire_ligne_non_commerciale AFTER INSERT OR UPDATE ON logistique."T_InventaireLigne" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();
COMMENT ON VIEW logistique."V_BonInventaire" IS 'Bons correcteurs et compensateurs rattachés aux comptages ; flux physiques internes sans facturation ni retour commercial.';
COMMENT ON COLUMN logistique."V_BonInventaire"."ID_Commande" IS 'Identité du bon de stock interne ; un bon peut regrouper plusieurs articles comptés.';
COMMENT ON COLUMN logistique."V_BonInventaire"."ID_Inventaire" IS 'Comptage physique à l’origine du bon ou de sa compensation.';
COMMENT ON COLUMN logistique."V_BonInventaire"."RoleBon" IS 'Correction du comptage ou compensation d’une annulation ; ne désigne pas une vente ou un retour client.';
COMMENT ON FUNCTION logistique.fn_bon_inventaire(integer) IS 'Classe un bon selon ses liens de comptage, sans heuristique de référence texte. VOLATILE conserve un instantané frais après attente du verrou concurrent.';
COMMENT ON FUNCTION logistique.verifier_bon_inventaire_non_commercial() IS 'Verrouille les bons dans un ordre stable et refuse les liens commerciaux dans les deux sens, y compris les rattachements différés de la transaction.';
COMMENT ON TRIGGER aa_08_facture_inventaire_non_commercial ON logistique."T_Facture" IS 'Une correction ou compensation d’inventaire ne produit pas de facture commerciale.';
COMMENT ON TRIGGER aa_08_retour_inventaire_non_commercial ON logistique."T_RetourBon" IS 'Les bons d’inventaire sont exclus des origines et des contre-bons des retours clients.';
COMMENT ON TRIGGER aa_08_code_facture_inventaire ON logistique."T_Commande" IS 'Interdit aussi l’attribution directe d’un code de facture à un bon d’inventaire.';
COMMENT ON TRIGGER aa_08_ligne_inventaire_non_commercial ON logistique."T_InventaireLigne" IS 'Refuse un bon déjà facturé ou lié à un retour lors du rattachement au comptage.';
COMMENT ON TRIGGER inventaire_ligne_non_commerciale ON logistique."T_InventaireLigne" IS 'Contrôle au terme de la transaction les liens inventaire/facture/retour, quel que soit leur ordre de création.';
COMMENT ON INDEX logistique.ix_inventaire_ligne_bon_correction IS 'Accélère la classification d’un bon d’écart vers son inventaire sans recherche textuelle.';
COMMIT;
