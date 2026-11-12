BEGIN;
SET LOCAL lock_timeout='10s';
ALTER TABLE logistique."T_Inventaire"
 ADD COLUMN "AnnuleLe" timestamptz,
 ADD COLUMN "ID_AnnulateurFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 ADD COLUMN "MotifAnnulation" text,
 ADD COLUMN "AnnulationRequest" uuid,
 ADD COLUMN "AnnulationHash" text;
ALTER TABLE logistique."T_InventaireLigne"
 ADD COLUMN "ID_CommandeAnnulationFk" integer REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT;
CREATE UNIQUE INDEX inventaire_annulation_bon_unique ON logistique."T_InventaireLigne"("ID_CommandeAnnulationFk") WHERE "ID_CommandeAnnulationFk" IS NOT NULL;
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT conname FROM pg_constraint WHERE conrelid='logistique."T_Inventaire"'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%Etat%' LOOP
 EXECUTE format('ALTER TABLE logistique."T_Inventaire" DROP CONSTRAINT %I',r.conname);END LOOP;
END $$;
ALTER TABLE logistique."T_Inventaire" ADD CONSTRAINT inventaire_etat CHECK("Etat" IN ('brouillon','valide','annule')),
 ADD CONSTRAINT inventaire_validation CHECK(("Etat" IN ('valide','annule'))=("ValideLe" IS NOT NULL AND "ID_ValidateurFk" IS NOT NULL AND "ValidationRequest" IS NOT NULL AND "ValidationHash" IS NOT NULL)),
 ADD CONSTRAINT inventaire_annulation CHECK(
  ("Etat"='annule' AND "AnnuleLe" IS NOT NULL AND "ID_AnnulateurFk" IS NOT NULL AND "MotifAnnulation" IS NOT NULL AND length(btrim("MotifAnnulation")) BETWEEN 1 AND 1000 AND "AnnulationRequest" IS NOT NULL AND "AnnulationHash" IS NOT NULL)
  OR ("Etat"<>'annule' AND "AnnuleLe" IS NULL AND "ID_AnnulateurFk" IS NULL AND "MotifAnnulation" IS NULL AND "AnnulationRequest" IS NULL AND "AnnulationHash" IS NULL));

CREATE OR REPLACE FUNCTION logistique.verifier_inventaire() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE h record; a record; BEGIN
 IF TG_TABLE_NAME='T_Inventaire' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Inventaire historique conservé' USING ERRCODE='23514';END IF;
  IF TG_OP='INSERT' AND NEW."Etat"<>'brouillon' THEN RAISE EXCEPTION 'Créez un comptage avant sa validation' USING ERRCODE='23514';END IF;
  IF TG_OP='UPDATE' THEN
   IF OLD."IdEntiteFk"<>NEW."IdEntiteFk" OR OLD."ID_UserFk"<>NEW."ID_UserFk" OR OLD."Etat"='annule' OR
    (OLD."Etat"='valide' AND (NEW."Etat"<>'annule' OR
      (to_jsonb(OLD)-ARRAY['Etat','AnnuleLe','ID_AnnulateurFk','MotifAnnulation','AnnulationRequest','AnnulationHash']) IS DISTINCT FROM
      (to_jsonb(NEW)-ARRAY['Etat','AnnuleLe','ID_AnnulateurFk','MotifAnnulation','AnnulationRequest','AnnulationHash']))) OR
    (OLD."Etat"='brouillon' AND NEW."Etat"='annule')
   THEN RAISE EXCEPTION 'Inventaire historique ou propriétaire immuable' USING ERRCODE='23514';END IF;
   NEW."Version"=OLD."Version"+1;NEW."ModifieLe"=clock_timestamp();
  END IF;RETURN NEW;
 END IF;
 IF TG_OP='UPDATE' AND (OLD."ID_InventaireFk"<>NEW."ID_InventaireFk" OR OLD."ID_ArticleFk"<>NEW."ID_ArticleFk") THEN
  RAISE EXCEPTION 'Identité de ligne conservée' USING ERRCODE='23514';END IF;
 SELECT * INTO h FROM logistique."T_Inventaire" WHERE "ID_Inventaire"=COALESCE(NEW."ID_InventaireFk",OLD."ID_InventaireFk") FOR UPDATE;
 IF h."Etat"='annule' AND TG_OP='UPDATE' AND OLD."ID_CommandeAnnulationFk" IS NULL AND NEW."ID_CommandeAnnulationFk" IS NOT NULL AND
  (to_jsonb(OLD)-'ID_CommandeAnnulationFk')=(to_jsonb(NEW)-'ID_CommandeAnnulationFk') THEN RETURN NEW;END IF;
 IF h."Etat"<>'brouillon' THEN RAISE EXCEPTION 'Un inventaire validé est conservé' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 IF NEW."ID_CommandeAnnulationFk" IS NOT NULL THEN RAISE EXCEPTION 'Annulation réservée à un inventaire validé' USING ERRCODE='23514';END IF;
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk";
 IF a."IdEntiteFk"<>h."IdEntiteFk" THEN RAISE EXCEPTION 'Article hors entreprise de l’inventaire' USING ERRCODE='23514';END IF;
 PERFORM logistique.fn_verifier_quantite(a."ID_UniteFk",NEW."QteTheorique");PERFORM logistique.fn_verifier_quantite(a."ID_UniteFk",NEW."QteComptee");
 IF NEW."ID_CommandeCorrectionFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Commande" c JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=c."ID_Commande"
  JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk"
  WHERE c."ID_Commande"=NEW."ID_CommandeCorrectionFk" AND c."IdEntiteFk"=h."IdEntiteFk" AND d."ID_ArticleFk"=NEW."ID_ArticleFk"
  AND d."QteCmdDetail"=abs(NEW."QteComptee"-NEW."QteTheorique") AND
   (NEW."QteComptee">NEW."QteTheorique" AND g."AbrGenerique" ILIKE 'entr%' OR NEW."QteComptee"<NEW."QteTheorique" AND g."AbrGenerique" ILIKE 'sort%')) THEN RAISE EXCEPTION 'Bon d’écart incompatible' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION logistique.controler_inventaire_valide() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE h record;l record;o record;n record; BEGIN
 IF TG_TABLE_NAME='T_Inventaire' THEN
  SELECT * INTO h FROM logistique."T_Inventaire" WHERE "ID_Inventaire"=NEW."ID_Inventaire";
 ELSE
  SELECT * INTO h FROM logistique."T_Inventaire" WHERE "ID_Inventaire"=COALESCE(NEW."ID_InventaireFk",OLD."ID_InventaireFk");
 END IF;
 IF h."Etat" IN ('valide','annule') AND (NOT EXISTS(SELECT FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=h."ID_Inventaire") OR
  EXISTS(SELECT FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=h."ID_Inventaire" AND ("QteComptee"<>"QteTheorique")<>("ID_CommandeCorrectionFk" IS NOT NULL))) THEN
 RAISE EXCEPTION 'Chaque écart doit posséder son bon correcteur unique' USING ERRCODE='23514';END IF;
 IF h."Etat"<>'annule' THEN RETURN NULL;END IF;
 FOR l IN SELECT * FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=h."ID_Inventaire" LOOP
  IF (l."QteComptee"<>l."QteTheorique")<>(l."ID_CommandeAnnulationFk" IS NOT NULL) THEN RAISE EXCEPTION 'Compensation manquante ou superflue' USING ERRCODE='23514';END IF;
  IF l."ID_CommandeAnnulationFk" IS NULL THEN CONTINUE;END IF;
  SELECT m.* INTO o FROM logistique."V_MouvementStock" m WHERE "ID_cmdFk"=l."ID_CommandeCorrectionFk" AND "ID_ArticleFk"=l."ID_ArticleFk";
  SELECT m.* INTO n FROM logistique."V_MouvementStock" m WHERE "ID_cmdFk"=l."ID_CommandeAnnulationFk" AND "ID_ArticleFk"=l."ID_ArticleFk";
  IF o."ID_Mvt" IS NULL OR n."ID_Mvt" IS NULL OR n."SigneStock"<>-o."SigneStock" OR n."QteMvt"<>o."QteMvt" OR NOT EXISTS(
   SELECT FROM logistique."T_Commande" c JOIN logistique."T_Commande" oldc ON oldc."ID_Commande"=l."ID_CommandeCorrectionFk"
   JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=c."ID_Commande"
   JOIN logistique."T_CommandeDetail" od ON od."ID_CmdFk"=oldc."ID_Commande" AND od."ID_ArticleFk"=d."ID_ArticleFk"
   WHERE c."ID_Commande"=l."ID_CommandeAnnulationFk" AND c."IdEntiteFk"=h."IdEntiteFk" AND c."ID_DeviseFk"=oldc."ID_DeviseFk"
    AND d."ID_ArticleFk"=l."ID_ArticleFk" AND d."PUCmdDetail" IS NOT DISTINCT FROM od."PUCmdDetail"
    AND (SELECT count(*) FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=c."ID_Commande")=1)
  THEN RAISE EXCEPTION 'Compensation incompatible avec le bon d’origine' USING ERRCODE='23514';END IF;
  IF EXISTS((SELECT "ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=o."ID_Mvt" EXCEPT SELECT "ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=n."ID_Mvt")
   UNION ALL (SELECT "ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=n."ID_Mvt" EXCEPT SELECT "ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=o."ID_Mvt"))
  THEN RAISE EXCEPTION 'La compensation conserve les lots d’origine' USING ERRCODE='23514';END IF;
 END LOOP;RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER inventaire_ligne_compensation_complete
 AFTER INSERT OR UPDATE OR DELETE ON logistique."T_InventaireLigne"
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_inventaire_valide();

CREATE OR REPLACE FUNCTION logistique.proteger_bon_inventaire() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE targets integer[]; BEGIN
 IF TG_TABLE_NAME='T_Commande' THEN targets=ARRAY[OLD."ID_Commande"];
 ELSIF TG_TABLE_NAME='T_CommandeDetail' THEN targets=ARRAY[NEW."ID_CmdFk",OLD."ID_CmdFk"];
 ELSIF TG_TABLE_NAME='T_MouvementLot' THEN SELECT array_agg("ID_cmdFk") INTO targets FROM logistique."T_Mouvement" WHERE "ID_Mvt" IN (NEW."ID_MvtFk",OLD."ID_MvtFk");
 ELSE targets=ARRAY[NEW."ID_cmdFk",OLD."ID_cmdFk"];END IF;
 IF EXISTS(SELECT FROM logistique."T_InventaireLigne" l JOIN logistique."T_Inventaire" h ON h."ID_Inventaire"=l."ID_InventaireFk"
  WHERE (l."ID_CommandeCorrectionFk"=ANY(targets) OR l."ID_CommandeAnnulationFk"=ANY(targets)) AND h."Etat" IN ('valide','annule')) THEN
 RAISE EXCEPTION 'Les bons et mouvements de cet inventaire sont conservés' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;
CREATE TRIGGER aa_inventaire_lot_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_inventaire();

DO $$ DECLARE def text; BEGIN
 def=rtrim(pg_get_viewdef('logistique."V_Inventaire"'::regclass,true),E';\n ');
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_Inventaire" AS SELECT v.*,h."AnnuleLe",h."ID_AnnulateurFk",h."MotifAnnulation",h."AnnulationRequest",h."AnnulationHash" FROM ('||def||') v JOIN logistique."T_Inventaire" h USING ("ID_Inventaire")';
 def=rtrim(pg_get_viewdef('logistique."V_InventaireLigne"'::regclass,true),E';\n ');
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_InventaireLigne" AS SELECT v.*,l."ID_CommandeAnnulationFk",c."CodeCmd" AS "CodeAnnulation" FROM ('||def||') v JOIN logistique."T_InventaireLigne" l USING ("ID_InventaireFk","ID_ArticleFk") LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=l."ID_CommandeAnnulationFk"';
END $$;
COMMENT ON COLUMN logistique."T_Inventaire"."AnnuleLe" IS 'Date et heure de l’annulation ; la validation originale reste conservée.';
COMMENT ON COLUMN logistique."T_Inventaire"."ID_AnnulateurFk" IS 'Administrateur autorisé ayant demandé l’annulation dans cette entreprise.';
COMMENT ON COLUMN logistique."T_Inventaire"."MotifAnnulation" IS 'Motif obligatoire, conservé avec les bons compensateurs.';
COMMENT ON COLUMN logistique."T_Inventaire"."AnnulationRequest" IS 'Demande idempotente : un rejeu identique ne recrée pas les mouvements.';
COMMENT ON COLUMN logistique."T_Inventaire"."AnnulationHash" IS 'Empreinte de la demande, incluant motif et version initiale.';
COMMENT ON COLUMN logistique."T_InventaireLigne"."ID_CommandeAnnulationFk" IS 'Bon inverse unique de cette ligne ; même quantité, prix, devise et lots que la correction originale.';
COMMENT ON INDEX logistique.inventaire_annulation_bon_unique IS 'Un bon compensateur par ligne d’inventaire, sans réutilisation.';
COMMENT ON FUNCTION logistique.verifier_inventaire() IS 'Autorise une unique annulation motivée, conserve comptage et validation, verrouille le propriétaire et les lignes historiques.';
COMMENT ON FUNCTION logistique.controler_inventaire_valide() IS 'Contrôle différé de complétude et inversion exacte des mouvements, prix, devise et lots lors de l’annulation.';
COMMENT ON FUNCTION logistique.proteger_bon_inventaire() IS 'Préserve les bons originaux et inverses, leurs lignes, mouvements et ventilations de lots.';
COMMENT ON TRIGGER aa_inventaire_lot_protection ON logistique."T_MouvementLot" IS 'Interdit la modification des lots des corrections et annulations historiques.';
COMMENT ON VIEW logistique."V_Inventaire" IS 'Registre des comptages, validations et annulations tracées par entreprise.';
COMMENT ON VIEW logistique."V_InventaireLigne" IS 'Comptage original, précision du référentiel, bon correcteur et bon inverse d’annulation.';
COMMENT ON CONSTRAINT inventaire_etat ON logistique."T_Inventaire" IS 'Brouillon, validation conservée ou validation annulée par compensation.';
COMMENT ON CONSTRAINT inventaire_validation ON logistique."T_Inventaire" IS 'Conserve les preuves de validation après annulation.';
COMMENT ON CONSTRAINT inventaire_annulation ON logistique."T_Inventaire" IS 'Annulation complète, motivée, datée et identifiée ; aucune métadonnée d’annulation sur les autres états.';
COMMENT ON COLUMN logistique."V_Inventaire"."AnnuleLe" IS 'Date et heure de l’annulation de validation.';
COMMENT ON COLUMN logistique."V_Inventaire"."ID_AnnulateurFk" IS 'Administrateur ayant annulé la validation.';
COMMENT ON COLUMN logistique."V_Inventaire"."MotifAnnulation" IS 'Justification obligatoire conservée dans l’historique.';
COMMENT ON COLUMN logistique."V_Inventaire"."AnnulationRequest" IS 'Identifiant de demande empêchant le double traitement.';
COMMENT ON COLUMN logistique."V_Inventaire"."AnnulationHash" IS 'Empreinte du contenu de la demande d’annulation.';
COMMENT ON COLUMN logistique."V_InventaireLigne"."ID_CommandeAnnulationFk" IS 'Identifiant du bon compensateur de cette ligne.';
COMMENT ON COLUMN logistique."V_InventaireLigne"."CodeAnnulation" IS 'Code consultable du bon compensateur de cette ligne.';
COMMENT ON TRIGGER inventaire_ligne_compensation_complete ON logistique."T_InventaireLigne" IS 'Recontrôle la complétude des corrections et compensations après toute modification des lignes, y compris un accès SQL direct.';
COMMIT;
