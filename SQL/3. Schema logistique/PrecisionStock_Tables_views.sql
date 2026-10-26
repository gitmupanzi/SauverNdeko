-- Définitions cibles de précision du stock, version 20261026_10 ; aucune donnée.
-- Référence documentaire du domaine, après les dépendances logistiques jusqu’à 09.
-- Base existante : appliquer uniquement la migration 20261026_10, jamais cet extrait.
-- Installation neuve : utiliser le paquet courant ou toute la chaîne de migrations.
SET check_function_bodies=false;

CREATE TABLE logistique."T_PrecisionStock"(
 "ID_PrecisionStock" integer GENERATED ALWAYS AS IDENTITY,
 "ID_UniteFk" integer NOT NULL,
 "DecimalesStock" smallint NOT NULL DEFAULT 0,
 "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT precision_stock_pk PRIMARY KEY("ID_PrecisionStock"),
 CONSTRAINT precision_stock_unite_unique UNIQUE("ID_UniteFk"),
 CONSTRAINT precision_stock_unite_fk FOREIGN KEY("ID_UniteFk")
  REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE RESTRICT ON DELETE RESTRICT,
 CONSTRAINT precision_stock_decimales CHECK("DecimalesStock" BETWEEN 0 AND 3)
);

CREATE FUNCTION logistique.fn_precision_stock_compatible(p_unite integer,p_decimales integer)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 IF p_decimales IS NULL OR p_decimales NOT BETWEEN 0 AND 3 THEN
  RAISE EXCEPTION 'Précision de zéro à trois décimales requise' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_UniteFk"=p_unite AND
  (a."QteArticle"<>round(a."QteArticle",p_decimales) OR a."QteMinArticle"<>round(a."QteMinArticle",p_decimales)))
 OR EXISTS(SELECT FROM logistique."T_CommandeDetail" d JOIN logistique."T_Article" a ON a."ID_Article"=d."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND d."QteCmdDetail"<>round(d."QteCmdDetail",p_decimales))
 OR EXISTS(SELECT FROM logistique."T_Mouvement" m JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND m."QteMvt"<>round(m."QteMvt",p_decimales))
 OR EXISTS(SELECT FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
  JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND ml."Quantite"<>round(ml."Quantite",p_decimales))
 OR EXISTS(SELECT FROM logistique."T_InventaireLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND
  (l."QteTheorique"<>round(l."QteTheorique",p_decimales) OR l."QteComptee"<>round(l."QteComptee",p_decimales)))
 OR EXISTS(SELECT FROM logistique."T_FactureLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND
  (l."QteSortie"<>round(l."QteSortie",p_decimales)
   OR l."QteRetourAvantFacture"<>round(l."QteRetourAvantFacture",p_decimales)
   OR l."QteFacturee"<>round(l."QteFacturee",p_decimales)))
 OR EXISTS(SELECT FROM logistique."T_AvoirLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND l."Quantite"<>round(l."Quantite",p_decimales))
 OR EXISTS(SELECT FROM logistique."T_ValorisationOuverture" o JOIN logistique."T_Article" a ON a."ID_Article"=o."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND o."QuantiteOuverture"<>round(o."QuantiteOuverture",p_decimales)) THEN
  RAISE EXCEPTION 'La précision est incompatible avec les quantités historiques' USING ERRCODE='23514';
 END IF;
END $$;

CREATE FUNCTION logistique.tr_precision_stock() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  RAISE EXCEPTION 'Conservez la politique ; choisissez explicitement zéro décimale si nécessaire' USING ERRCODE='23514';
 END IF;
 IF TG_OP='UPDATE' AND
 (NEW."ID_PrecisionStock"<>OLD."ID_PrecisionStock" OR NEW."ID_UniteFk"<>OLD."ID_UniteFk") THEN
  RAISE EXCEPTION 'L’identité et l’unité de la politique sont conservées' USING ERRCODE='23514';
 END IF;
 -- Même clé de verrou que fn_verifier_quantite : la réduction attend les opérations en cours.
 PERFORM 1 FROM referentiel."T_Generique"
  WHERE "ID_Generique"=NEW."ID_UniteFk" AND "ID_CategorieGeneriqueFk"=34 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Une unité du référentiel Unités est requise' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."DecimalesStock" IS NOT DISTINCT FROM OLD."DecimalesStock" THEN
  NEW."ModifieLe"=OLD."ModifieLe";RETURN NEW;
 END IF;
 PERFORM logistique.fn_precision_stock_compatible(NEW."ID_UniteFk",NEW."DecimalesStock");
 NEW."ModifieLe"=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER precision_stock_integrite BEFORE INSERT OR UPDATE OR DELETE
 ON logistique."T_PrecisionStock" FOR EACH ROW EXECUTE FUNCTION logistique.tr_precision_stock();

CREATE FUNCTION logistique.tr_proteger_unite_precision_stock() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW."ID_Generique"=OLD."ID_Generique" AND NEW."ID_CategorieGeneriqueFk"=OLD."ID_CategorieGeneriqueFk" THEN RETURN NEW;END IF;
 IF OLD."ID_CategorieGeneriqueFk"=34 AND
 (EXISTS(SELECT FROM logistique."T_PrecisionStock" WHERE "ID_UniteFk"=OLD."ID_Generique")
 OR EXISTS(SELECT FROM logistique."T_Article" WHERE "ID_UniteFk"=OLD."ID_Generique")) THEN
  RAISE EXCEPTION 'La catégorie et l’identité d’une unité utilisée sont conservées' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER precision_stock_reference_integrite BEFORE UPDATE OF "ID_Generique","ID_CategorieGeneriqueFk" OR DELETE
 ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_unite_precision_stock();

CREATE VIEW logistique."V_PrecisionStock" AS
 SELECT p."ID_PrecisionStock",g."ID_Generique" AS "ID_UniteFk",
 g."NomGenerique" AS "Unite",g."AbrGenerique" AS "Abreviation",
 COALESCE(p."DecimalesStock",0)::smallint AS "DecimalesStock",p."ModifieLe",
 g."ValideGenerique" AS "ValideUnite"
 FROM referentiel."T_Generique" g LEFT JOIN logistique."T_PrecisionStock" p ON p."ID_UniteFk"=g."ID_Generique"
 WHERE g."ID_CategorieGeneriqueFk"=34;

CREATE OR REPLACE FUNCTION logistique.fn_verifier_quantite(p_unite integer,p_qte numeric)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d integer;
BEGIN
 IF p_qte IS NULL THEN RETURN;END IF;
 IF p_qte<0 OR p_qte::text IN ('NaN','Infinity','-Infinity') OR p_qte>99999999999.999 OR p_qte<>round(p_qte,3) THEN
  RAISE EXCEPTION 'Quantité hors précision' USING ERRCODE='23514';
 END IF;
 PERFORM 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=p_unite AND "ID_CategorieGeneriqueFk"=34 FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unité de stock requise' USING ERRCODE='23514';END IF;
 SELECT "DecimalesStock" INTO d FROM logistique."V_PrecisionStock" WHERE "ID_UniteFk"=p_unite;
 IF d IS NULL OR p_qte<>round(p_qte,d) THEN
  RAISE EXCEPTION 'Quantité incompatible avec la précision de son unité' USING ERRCODE='23514';
 END IF;
END $$;

CREATE OR REPLACE VIEW logistique."V_InventaireLigne" AS
 SELECT l."ID_InventaireFk",l."ID_ArticleFk",l."QteTheorique",l."QteComptee",l."PUCorrection",
 l."Lots",l."Justification",l."ID_CommandeCorrectionFk",l."QteComptee"-l."QteTheorique" AS "Ecart",
 a."IdEntiteFk",a."NomArticle",a."CodeArticleInterne",a."ID_UniteFk",g."AbrGenerique" AS "Unite",
 a."QteArticle" AS "StockActuel",COALESCE(p."DecimalesStock",0) AS "Decimales",
 c."CodeCmd" AS "CodeCorrection",l."ID_CommandeAnnulationFk",ca."CodeCmd" AS "CodeAnnulation"
 FROM logistique."T_InventaireLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
 LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=a."ID_UniteFk"
 LEFT JOIN logistique."V_PrecisionStock" p ON p."ID_UniteFk"=a."ID_UniteFk"
 LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=l."ID_CommandeCorrectionFk"
 LEFT JOIN logistique."T_Commande" ca ON ca."ID_Commande"=l."ID_CommandeAnnulationFk";


COMMENT ON TABLE logistique."T_PrecisionStock" IS 'Politique logistique partagée de précision des quantités par unité du référentiel ; une ligne au plus par unité, de zéro à trois décimales, sans variation des stocks.';
COMMENT ON COLUMN logistique."T_PrecisionStock"."ID_PrecisionStock" IS 'Identité technique de la politique ; distincte de l’identifiant de l’unité, attribuée automatiquement et immuable.';
COMMENT ON COLUMN logistique."T_PrecisionStock"."ID_UniteFk" IS 'Unité de stock partagée : FK vers referentiel.T_Generique.ID_Generique, limitée à la catégorie Unités (34), comme T_Article.ID_UniteFk.';
COMMENT ON COLUMN logistique."T_PrecisionStock"."DecimalesStock" IS 'Nombre explicite de décimales autorisées, entre zéro et trois ; une réduction incompatible avec les quantités courantes ou historiques est refusée.';
COMMENT ON COLUMN logistique."T_PrecisionStock"."ModifieLe" IS 'Horodatage du dernier changement effectif de précision ; date source conservée à la reprise, ou date réelle d’initialisation en l’absence de réglage antérieur.';
COMMENT ON CONSTRAINT precision_stock_pk ON logistique."T_PrecisionStock" IS 'Clé technique unique de politique de précision.';
COMMENT ON CONSTRAINT precision_stock_unite_unique ON logistique."T_PrecisionStock" IS 'Une politique partagée au plus par unité de stock.';
COMMENT ON CONSTRAINT precision_stock_unite_fk ON logistique."T_PrecisionStock" IS 'Référence réelle à la même nomenclature d’unités que les articles ; suppression et changement d’identité refusés.';
COMMENT ON CONSTRAINT precision_stock_decimales ON logistique."T_PrecisionStock" IS 'Précision physique bornée entre zéro et trois décimales.';
COMMENT ON INDEX logistique.precision_stock_pk IS 'Accès à une politique par son identité technique.';
COMMENT ON INDEX logistique.precision_stock_unite_unique IS 'Accès et unicité de la politique par unité du référentiel.';
COMMENT ON SEQUENCE logistique."T_PrecisionStock_ID_PrecisionStock_seq" IS 'Identités techniques des politiques de précision, indépendantes des identifiants d’unités.';
COMMENT ON FUNCTION logistique.fn_precision_stock_compatible(integer,integer) IS 'Contrôle sans écriture de la compatibilité d’une précision avec stock, seuils, lignes, mouvements, lots, comptages, instantanés de facture, avoirs et arrêtés de valorisation de l’unité.';
COMMENT ON FUNCTION logistique.tr_precision_stock() IS 'Verrouille l’unité, protège l’identité, interdit la suppression et toute précision incompatible ; horodate seulement les changements effectifs, sans effet de stock.';
COMMENT ON TRIGGER precision_stock_integrite ON logistique."T_PrecisionStock" IS 'Protection de la politique par unité, y compris en SQL direct ; insertion et modification sérialisées avec les validations de quantités.';
COMMENT ON FUNCTION logistique.tr_proteger_unite_precision_stock() IS 'Conserve la catégorie et l’identité d’une unité référencée par une politique ou un article, sans bloquer la modification de son libellé.';
COMMENT ON TRIGGER precision_stock_reference_integrite ON referentiel."T_Generique" IS 'Protège les unités utilisées sans placer de paramètre logistique dans la table de nomenclature.';
COMMENT ON VIEW logistique."V_PrecisionStock" IS 'Lecture commune au grain unité de la catégorie Unités : politique explicite, identité et date ; zéro décimale si une nouvelle unité n’est pas encore paramétrée.';
COMMENT ON COLUMN logistique."V_PrecisionStock"."ID_PrecisionStock" IS 'Identité de la politique explicite, NULL si l’unité utilise encore le défaut entier.';
COMMENT ON COLUMN logistique."V_PrecisionStock"."ID_UniteFk" IS 'Identité unique de l’unité du référentiel ; clé logique de cette vue.';
COMMENT ON COLUMN logistique."V_PrecisionStock"."Unite" IS 'Libellé courant de l’unité du référentiel.';
COMMENT ON COLUMN logistique."V_PrecisionStock"."Abreviation" IS 'Abréviation courante de l’unité du référentiel.';
COMMENT ON COLUMN logistique."V_PrecisionStock"."DecimalesStock" IS 'Précision appliquée : politique explicite de zéro à trois décimales, ou zéro en l’absence de politique.';
COMMENT ON COLUMN logistique."V_PrecisionStock"."ModifieLe" IS 'Date du réglage explicite ou de son initialisation ; NULL pour une unité encore sans politique.';
COMMENT ON COLUMN logistique."V_PrecisionStock"."ValideUnite" IS 'Validité courante de la valeur Unité ; les unités inactives restent lisibles pour l’historique.';
COMMENT ON FUNCTION logistique.fn_verifier_quantite(integer,numeric) IS 'Validation exacte d’une quantité physique par la politique logistique de son unité ; verrou partagé commun à la configuration, zéro décimale si aucune politique.';
COMMENT ON VIEW logistique."V_InventaireLigne" IS 'Comptage, écart et bon correcteur au grain article/inventaire ; précision provenant de V_PrecisionStock, sans variation des colonnes historiques.';
COMMENT ON COLUMN logistique."V_InventaireLigne"."Decimales" IS 'Précision de comptage fournie par la politique logistique commune de l’unité ; zéro pour une unité non paramétrée.';
