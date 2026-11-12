BEGIN;
SET LOCAL lock_timeout='10s';
LOCK TABLE referentiel."T_Generique",logistique."T_UniteStockPrecision" IN SHARE ROW EXCLUSIVE MODE;
ALTER TABLE referentiel."T_Generique" ADD COLUMN "DecimalesStock" smallint,
 ADD COLUMN "PrecisionStockModifieLe" timestamptz;
ALTER TABLE referentiel."T_Generique" ADD CONSTRAINT generique_precision_stock
 CHECK("DecimalesStock" IS NULL OR ("ID_CategorieGeneriqueFk"=34 AND "DecimalesStock" BETWEEN 0 AND 3));
UPDATE referentiel."T_Generique" g SET "DecimalesStock"=p."Decimales","PrecisionStockModifieLe"=p."ModifieLe"
 FROM logistique."T_UniteStockPrecision" p WHERE p."ID_UniteFk"=g."ID_Generique";
CREATE FUNCTION referentiel.verifier_precision_stock() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD."DecimalesStock" IS NOT NULL THEN RAISE EXCEPTION 'Conservez cette unité et sa précision historique' USING ERRCODE='23514';END IF;
  RETURN OLD;
 END IF;
 IF TG_OP='UPDATE' AND OLD."ID_CategorieGeneriqueFk"=34 AND
 (NEW."ID_CategorieGeneriqueFk"<>34 OR NEW."ID_Generique"<>OLD."ID_Generique") AND
 (OLD."DecimalesStock" IS NOT NULL OR EXISTS(SELECT FROM logistique."T_Article" WHERE "ID_UniteFk"=OLD."ID_Generique"))
 THEN RAISE EXCEPTION 'La catégorie et l’identité d’une unité utilisée sont conservées' USING ERRCODE='23514';END IF;
 IF NEW."ID_CategorieGeneriqueFk"<>34 THEN
  IF NEW."DecimalesStock" IS NOT NULL OR NEW."PrecisionStockModifieLe" IS NOT NULL THEN RAISE EXCEPTION 'Précision réservée aux unités' USING ERRCODE='23514';END IF;
  RETURN NEW;
 END IF;
 IF TG_OP='UPDATE' AND NEW."DecimalesStock" IS NOT DISTINCT FROM OLD."DecimalesStock" THEN
  NEW."PrecisionStockModifieLe"=OLD."PrecisionStockModifieLe";RETURN NEW;
 END IF;
 IF EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_UniteFk"=NEW."ID_Generique" AND
  (a."QteArticle"<>round(a."QteArticle",COALESCE(NEW."DecimalesStock",0)) OR a."QteMinArticle"<>round(a."QteMinArticle",COALESCE(NEW."DecimalesStock",0)))) OR
 EXISTS(SELECT FROM logistique."T_Mouvement" m JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE a."ID_UniteFk"=NEW."ID_Generique" AND m."QteMvt"<>round(m."QteMvt",COALESCE(NEW."DecimalesStock",0))) OR
 EXISTS(SELECT FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk" JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE a."ID_UniteFk"=NEW."ID_Generique" AND ml."Quantite"<>round(ml."Quantite",COALESCE(NEW."DecimalesStock",0))) THEN
 RAISE EXCEPTION 'La précision est incompatible avec les quantités historiques' USING ERRCODE='23514'; END IF;

 NEW."PrecisionStockModifieLe"=clock_timestamp();RETURN NEW;
END $$;
CREATE TRIGGER generique_precision_stock BEFORE INSERT OR UPDATE OR DELETE ON referentiel."T_Generique"
 FOR EACH ROW EXECUTE FUNCTION referentiel.verifier_precision_stock();
CREATE OR REPLACE FUNCTION logistique.fn_verifier_quantite(p_unite integer,p_qte numeric) RETURNS void LANGUAGE plpgsql AS $$
DECLARE d integer; BEGIN
 IF p_qte IS NULL THEN RETURN;END IF;
 IF p_qte<0 OR p_qte::text IN ('NaN','Infinity','-Infinity') OR p_qte>99999999999.999 OR p_qte<>round(p_qte,3)
 THEN RAISE EXCEPTION 'Quantité hors précision' USING ERRCODE='23514';END IF;
 SELECT COALESCE(g."DecimalesStock",0) INTO d FROM referentiel."T_Generique" g
 WHERE g."ID_Generique"=p_unite AND g."ID_CategorieGeneriqueFk"=34 FOR SHARE;
 IF d IS NULL OR p_qte<>round(p_qte,d) THEN RAISE EXCEPTION 'Quantité incompatible avec la précision de son unité' USING ERRCODE='23514';END IF;
END $$;
CREATE OR REPLACE VIEW logistique."V_InventaireLigne" AS SELECT l.*,l."QteComptee"-l."QteTheorique" AS "Ecart",a."IdEntiteFk",a."NomArticle",a."CodeArticleInterne",a."ID_UniteFk",g."AbrGenerique" AS "Unite",a."QteArticle" AS "StockActuel",COALESCE(g."DecimalesStock",0) AS "Decimales",c."CodeCmd" AS "CodeCorrection" FROM logistique."T_InventaireLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk" LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=a."ID_UniteFk" LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=l."ID_CommandeCorrectionFk";
DROP TABLE logistique."T_UniteStockPrecision" RESTRICT;
DROP FUNCTION logistique.verifier_precision_unite();
COMMENT ON COLUMN referentiel."T_Generique"."DecimalesStock" IS 'Précision des quantités pour une unité (catégorie 34), de zéro à trois décimales ; NULL conserve les quantités entières. Réduction refusée si incompatible avec le stock ou son historique.';
COMMENT ON COLUMN referentiel."T_Generique"."PrecisionStockModifieLe" IS 'Date et heure de la dernière modification de précision ; historique conservé lors du transfert depuis T_UniteStockPrecision.';
COMMENT ON CONSTRAINT generique_precision_stock ON referentiel."T_Generique" IS 'Précision 0 à 3 réservée aux unités du référentiel commun.';
COMMENT ON FUNCTION referentiel.verifier_precision_stock() IS 'Préserve les unités utilisées et refuse toute réduction de précision incompatible avec les quantités existantes.';
COMMENT ON TRIGGER generique_precision_stock ON referentiel."T_Generique" IS 'Contrôle de la précision partagée et de son historique, sans modification des stocks.';
COMMENT ON FUNCTION logistique.fn_verifier_quantite(integer,numeric) IS 'Contrôle exact des quantités avec verrou partagé sur leur unité du référentiel ; zéro décimale par défaut.';
COMMENT ON VIEW logistique."V_InventaireLigne" IS 'Comptage, écart et bon correcteur ; précision provenant de l’unité du référentiel commun.';
COMMIT;
