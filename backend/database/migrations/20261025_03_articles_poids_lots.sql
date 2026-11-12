-- Poids unitaire transversal et ventilation des mouvements par lot fournisseur/fabricant.
BEGIN;
SET LOCAL lock_timeout='3s';
ALTER TABLE logistique."T_Article" ADD COLUMN "PoidsUnitaire" numeric(14,6),
 ADD COLUMN "ID_UnitePoidsFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 ADD COLUMN "InformationArticle" text,
 ADD CONSTRAINT article_poids_coherent CHECK (("PoidsUnitaire" IS NULL)=("ID_UnitePoidsFk" IS NULL) AND ("PoidsUnitaire" IS NULL OR "PoidsUnitaire">=0));
CREATE TABLE logistique."T_LotArticle" (
 "ID_LotArticle" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_ArticleFk" integer NOT NULL REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 "NumeroLot" varchar(100) NOT NULL CHECK (btrim("NumeroLot")<>''),
 "DatePeremptionLot" date,
 "Actif" boolean NOT NULL DEFAULT true,
 "CreeLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX lot_article_numero_unique ON logistique."T_LotArticle" ("ID_ArticleFk",lower(btrim("NumeroLot")));
CREATE TABLE logistique."T_MouvementLot" (
 "ID_MvtFk" integer NOT NULL REFERENCES logistique."T_Mouvement"("ID_Mvt") ON DELETE CASCADE,
 "ID_LotArticleFk" integer NOT NULL REFERENCES logistique."T_LotArticle"("ID_LotArticle") ON DELETE RESTRICT,
 "Quantite" integer NOT NULL CHECK ("Quantite">0),
 PRIMARY KEY ("ID_MvtFk","ID_LotArticleFk")
);
CREATE INDEX mouvement_lot_lot ON logistique."T_MouvementLot" ("ID_LotArticleFk");
CREATE FUNCTION logistique.verifier_article_poids() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW."ID_UnitePoidsFk" IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."ID_UnitePoidsFk" AND "ID_CategorieGeneriqueFk"=34 AND lower(btrim("AbrGenerique")) IN ('mg','g','kg','t')) THEN
 RAISE EXCEPTION 'Unité de masse requise pour le poids unitaire.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER article_poids_integrite BEFORE INSERT OR UPDATE OF "PoidsUnitaire","ID_UnitePoidsFk" ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_article_poids();
CREATE FUNCTION logistique.verifier_lot_rattachement() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' AND (OLD."ID_ArticleFk"<>NEW."ID_ArticleFk" OR OLD."ID_LotArticle"<>NEW."ID_LotArticle") THEN
 RAISE EXCEPTION 'Un lot ne peut pas être déplacé vers un autre article.' USING ERRCODE='23514';
 END IF;
 NEW."NumeroLot"=btrim(NEW."NumeroLot");
 RETURN NEW;
END;
$$;
CREATE TRIGGER lot_article_integrite BEFORE INSERT OR UPDATE ON logistique."T_LotArticle" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_lot_rattachement();
CREATE FUNCTION logistique.verrouiller_ventilation_lot() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE lot_id integer; article_id integer; mvt_article integer; mvt_id integer; mvt_sign integer;
BEGIN
 IF TG_OP='UPDATE' AND (OLD."ID_MvtFk"<>NEW."ID_MvtFk" OR OLD."ID_LotArticleFk"<>NEW."ID_LotArticleFk") THEN
 RAISE EXCEPTION 'Un rattachement de lot ne peut pas être transféré.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN lot_id=OLD."ID_LotArticleFk";mvt_id=OLD."ID_MvtFk";ELSE lot_id=NEW."ID_LotArticleFk";mvt_id=NEW."ID_MvtFk";END IF;
 SELECT "ID_ArticleFk" INTO article_id FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=lot_id;
 PERFORM 1 FROM logistique."T_Article" WHERE "ID_Article"=article_id FOR NO KEY UPDATE;
 PERFORM 1 FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=lot_id FOR NO KEY UPDATE;
 IF TG_OP<>'DELETE' THEN
 SELECT "ID_ArticleFk","SigneStock" INTO mvt_article,mvt_sign FROM logistique."V_MouvementStock" WHERE "ID_Mvt"=mvt_id;
 IF mvt_sign IS NULL OR mvt_sign NOT IN (-1,1) THEN RAISE EXCEPTION 'Sens du mouvement de lot inconnu.' USING ERRCODE='23514';END IF;
 IF article_id IS DISTINCT FROM mvt_article THEN RAISE EXCEPTION 'Le lot et le mouvement doivent concerner le même article.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
 END IF;
 RETURN OLD;
END;
$$;
CREATE TRIGGER mouvement_lot_verrou BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.verrouiller_ventilation_lot();
CREATE VIEW logistique."V_LotArticleStock" AS
 SELECT l."ID_LotArticle",l."ID_ArticleFk",l."NumeroLot",l."DatePeremptionLot",l."Actif",l."CreeLe",
 COALESCE(sum(ml."Quantite" * m."SigneStock"),0)::numeric AS "StockLot",
 COALESCE(sum(ml."Quantite") FILTER(WHERE m."SigneStock"=1),0)::numeric AS "QuantiteEntree",
 COALESCE(sum(ml."Quantite") FILTER(WHERE m."SigneStock"=-1),0)::numeric AS "QuantiteSortie"
 FROM logistique."T_LotArticle" l LEFT JOIN logistique."T_MouvementLot" ml ON ml."ID_LotArticleFk"=l."ID_LotArticle"
 LEFT JOIN logistique."V_MouvementStock" m ON m."ID_Mvt"=ml."ID_MvtFk" GROUP BY l."ID_LotArticle";
CREATE VIEW logistique."V_MouvementLot" AS
 SELECT ml."ID_MvtFk",ml."ID_LotArticleFk",l."ID_ArticleFk",l."NumeroLot",l."DatePeremptionLot",
 ml."Quantite",m."DateMvt",m."ID_cmdFk",m."SigneStock",
 (ml."Quantite"*m."SigneStock")::numeric AS "QuantiteSignee",m."NomArticle",m."CodeCmd"
 FROM logistique."T_MouvementLot" ml JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=ml."ID_LotArticleFk"
 JOIN logistique."V_MouvementStock" m ON m."ID_Mvt"=ml."ID_MvtFk";
CREATE FUNCTION logistique.controler_stock_lots() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE article_id integer; mvt_id integer; linked_total numeric; global_stock numeric; lot_stock numeric;
BEGIN
 IF TG_TABLE_NAME='T_Article' THEN article_id=NEW."ID_Article";
 ELSIF TG_TABLE_NAME='T_LotArticle' THEN article_id=NEW."ID_ArticleFk";
 ELSIF TG_TABLE_NAME='T_Mouvement' THEN
  IF TG_OP='DELETE' THEN article_id=OLD."ID_ArticleFk";mvt_id=OLD."ID_Mvt";ELSE article_id=NEW."ID_ArticleFk";mvt_id=NEW."ID_Mvt";END IF;
 ELSE
  IF TG_OP='DELETE' THEN mvt_id=OLD."ID_MvtFk";SELECT "ID_ArticleFk" INTO article_id FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=OLD."ID_LotArticleFk";
  ELSE mvt_id=NEW."ID_MvtFk";SELECT "ID_ArticleFk" INTO article_id FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=NEW."ID_LotArticleFk";END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
 JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=ml."ID_LotArticleFk" WHERE m."ID_ArticleFk"=article_id AND l."ID_ArticleFk"<>m."ID_ArticleFk") THEN
 RAISE EXCEPTION 'Lot et mouvement incompatibles.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_Mouvement" m JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
 WHERE m."ID_ArticleFk"=article_id GROUP BY m."ID_Mvt",m."QteMvt" HAVING sum(ml."Quantite")>m."QteMvt") THEN
 RAISE EXCEPTION 'La ventilation par lot dépasse la quantité du mouvement.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM logistique."V_LotArticleStock" WHERE "ID_ArticleFk"=article_id AND "StockLot"<0) THEN
 RAISE EXCEPTION 'Stock de lot insuffisant.' USING ERRCODE='23514';END IF;
 SELECT "QteArticle" INTO global_stock FROM logistique."T_Article" WHERE "ID_Article"=article_id;
 SELECT COALESCE(sum("StockLot"),0) INTO lot_stock FROM logistique."V_LotArticleStock" WHERE "ID_ArticleFk"=article_id;
 IF global_stock IS NOT NULL AND lot_stock>global_stock THEN
 RAISE EXCEPTION 'Une sortie doit préciser ses lots : le stock sans lot est insuffisant.' USING ERRCODE='23514';END IF;
 RETURN NULL;
END;
$$;
CREATE CONSTRAINT TRIGGER article_stock_lots AFTER INSERT OR UPDATE ON logistique."T_Article" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_stock_lots();
CREATE CONSTRAINT TRIGGER mouvement_stock_lots AFTER INSERT OR UPDATE OR DELETE ON logistique."T_Mouvement" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_stock_lots();
CREATE CONSTRAINT TRIGGER ventilation_stock_lots AFTER INSERT OR UPDATE OR DELETE ON logistique."T_MouvementLot" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_stock_lots();
CREATE CONSTRAINT TRIGGER lot_stock_lots AFTER INSERT OR UPDATE ON logistique."T_LotArticle" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_stock_lots();
COMMENT ON TABLE logistique."T_LotArticle" IS 'Lots identifiés par article et numéro reçu ; aucun stock copié sur cette table.';
COMMENT ON COLUMN logistique."T_LotArticle"."ID_LotArticle" IS 'Identifiant stable du lot.';
COMMENT ON COLUMN logistique."T_LotArticle"."ID_ArticleFk" IS 'Article auquel appartient le lot ; relation immuable.';
COMMENT ON COLUMN logistique."T_LotArticle"."NumeroLot" IS 'Numéro communiqué lors de la réception, unique pour cet article sans distinction de casse.';
COMMENT ON COLUMN logistique."T_LotArticle"."DatePeremptionLot" IS 'Date propre au lot ; NULL signifie non renseignée.';
COMMENT ON COLUMN logistique."T_LotArticle"."Actif" IS 'Disponibilité du lot pour de nouvelles saisies.';
COMMENT ON COLUMN logistique."T_LotArticle"."CreeLe" IS 'Instant de première identification du lot.';
COMMENT ON TABLE logistique."T_MouvementLot" IS 'Ventilation d’un mouvement existant par lot ; ne modifie jamais une seconde fois le stock global.';
COMMENT ON COLUMN logistique."T_MouvementLot"."ID_MvtFk" IS 'Mouvement source, créé par les triggers de stock existants.';
COMMENT ON COLUMN logistique."T_MouvementLot"."ID_LotArticleFk" IS 'Lot du même article que le mouvement.';
COMMENT ON COLUMN logistique."T_MouvementLot"."Quantite" IS 'Quantité entière positive affectée à ce lot dans le sens du mouvement.';
COMMENT ON VIEW logistique."V_LotArticleStock" IS 'Stock signé par lot issu exclusivement de la ventilation des mouvements existants.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."ID_LotArticle" IS 'Identifiant du lot.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."ID_ArticleFk" IS 'Article propriétaire du lot.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."NumeroLot" IS 'Numéro reçu avec les produits.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."DatePeremptionLot" IS 'Péremption propre au lot.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."Actif" IS 'Disponibilité du lot.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."CreeLe" IS 'Instant de première identification.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."StockLot" IS 'Somme des entrées et sorties ventilées de ce lot, dans l’unité de stock de l’article.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."QuantiteEntree" IS 'Total des entrées ventilées de ce lot.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."QuantiteSortie" IS 'Total des sorties ventilées de ce lot.';
COMMENT ON COLUMN logistique."V_MouvementLot"."NomArticle" IS 'Nom de l’article du mouvement.';
COMMENT ON COLUMN logistique."V_MouvementLot"."CodeCmd" IS 'Référence du bon de stock source.';
COMMENT ON VIEW logistique."V_MouvementLot" IS 'Traçabilité des numéros de lot par mouvement et bon de stock.';
COMMENT ON COLUMN logistique."V_MouvementLot"."ID_MvtFk" IS 'Mouvement source unique par ligne de bon, ou mouvement initial.';
COMMENT ON COLUMN logistique."V_MouvementLot"."ID_LotArticleFk" IS 'Lot ventilé.';
COMMENT ON COLUMN logistique."V_MouvementLot"."ID_ArticleFk" IS 'Article commun au lot et au mouvement.';
COMMENT ON COLUMN logistique."V_MouvementLot"."NumeroLot" IS 'Numéro de lot communiqué.';
COMMENT ON COLUMN logistique."V_MouvementLot"."DatePeremptionLot" IS 'Péremption du lot.';
COMMENT ON COLUMN logistique."V_MouvementLot"."Quantite" IS 'Quantité ventilée non signée.';
COMMENT ON COLUMN logistique."V_MouvementLot"."DateMvt" IS 'Date métier du mouvement source.';
COMMENT ON COLUMN logistique."V_MouvementLot"."ID_cmdFk" IS 'Bon source ; NULL pour un stock initial.';
COMMENT ON COLUMN logistique."V_MouvementLot"."SigneStock" IS 'Sens d’entrée (+1) ou sortie (-1) de la vue commune.';
COMMENT ON COLUMN logistique."V_MouvementLot"."QuantiteSignee" IS 'Quantité ventilée multipliée par le sens du mouvement.';
COMMENT ON COLUMN logistique."T_Article"."InformationArticle" IS 'Description complémentaire et caractéristiques libres du produit, distinctes des remarques ObsArticle. Ne remplace aucune donnée structurée de stock.';
COMMENT ON COLUMN logistique."T_Article"."PoidsUnitaire" IS 'Masse d’une unité de stock ; inconnue si NULL, indépendante de la quantité en stock.';
COMMENT ON COLUMN logistique."T_Article"."ID_UnitePoidsFk" IS 'Unité de masse du référentiel catégorie 34 (mg, g, kg ou t), distincte de l’unité de stock.';
COMMENT ON FUNCTION logistique.verifier_article_poids() IS 'Contrôle l’unité de masse sans transformer les quantités ni les prix.';
COMMENT ON FUNCTION logistique.verifier_lot_rattachement() IS 'Normalise le numéro du lot et interdit son transfert vers un autre article.';
COMMENT ON FUNCTION logistique.verrouiller_ventilation_lot() IS 'Verrouille article puis lot ; vérifie leur cohérence avec le mouvement et conserve le rattachement.';
COMMENT ON FUNCTION logistique.controler_stock_lots() IS 'Contrôle différé en fin de transaction : ventilation bornée par le mouvement, lots non négatifs et stock total ventilé inférieur ou égal au stock global. Aucun second effet sur le stock.';
COMMENT ON TRIGGER article_poids_integrite ON logistique."T_Article" IS 'Valide les unités de masse lors de la saisie du poids.';
COMMENT ON TRIGGER lot_article_integrite ON logistique."T_LotArticle" IS 'Relation article/lot immuable et numéro nettoyé.';
COMMENT ON TRIGGER mouvement_lot_verrou ON logistique."T_MouvementLot" IS 'Sérialise la ventilation par article et lot sans créer un mouvement supplémentaire.';
COMMENT ON TRIGGER article_stock_lots ON logistique."T_Article" IS 'Vérifie que les mises à jour du stock global conservent la cohérence des lots.';
COMMENT ON TRIGGER mouvement_stock_lots ON logistique."T_Mouvement" IS 'Vérifie les lots après création, correction, inversion de sens ou annulation de mouvement.';
COMMENT ON TRIGGER ventilation_stock_lots ON logistique."T_MouvementLot" IS 'Contrôle final des quantités ventilées dans la transaction source.';
COMMENT ON TRIGGER lot_stock_lots ON logistique."T_LotArticle" IS 'Contrôle la cohérence du stock du lot après sa création ou sa modification.';
CREATE OR REPLACE VIEW logistique."V_Article" AS SELECT a."ID_Article",
    a."DateHeureAuto",
    a."CodeArticleInterne",
    a."CodeArticleExterne",
    a."NomArticle",
    a."RefArticle",
    a."PhotoArticle",
    a."ObsArticle",
    a."ValideArticle",
    a."ID_TypeArticleFk",
    type_article."AbrGenerique" AS "AbrTypeArticle",
    type_article."NomGenerique" AS "TypeArticle",
    a."ID_CategorieArticleFk",
    categorie_article."AbrGenerique" AS "AbrCategorieArticle",
    categorie_article."NomGenerique" AS "CategorieArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    unite."NomGenerique" AS "Unite",
    COALESCE(a."QteArticle", 0::numeric)::numeric(14,3) AS "QteArticle",
    a."QteMinArticle",
    GREATEST(COALESCE(a."QteMinArticle", 0)::numeric - COALESCE(a."QteArticle", 0::numeric), 0::numeric)::numeric(14,3) AS "QteACommander",
        CASE
            WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 'Rupture'::text
            WHEN a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 'Stock faible'::text
            ELSE 'Disponible'::text
        END AS "EtatStock",
    COALESCE(a."QteArticle", 0::numeric) <= 0::numeric AS "EstRupture",
    a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric AS "EstAlerteStock",
        CASE
            WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 1
            WHEN a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 2
            ELSE 3
        END AS "PrioriteStock",
    COALESCE(a."PUArticle", 0::numeric)::numeric(12,2) AS "PUArticle",
    COALESCE(a."PVArticle", 0::numeric)::numeric(12,2) AS "PVArticle",
    (COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PUArticle", 0::numeric))::numeric(14,2) AS "ValeurStockAchat",
    (COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PVArticle", 0::numeric))::numeric(14,2) AS "ValeurStockVente",
    (COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric))::numeric(12,2) AS "MargeUnitaire",
        CASE
            WHEN COALESCE(a."PUArticle", 0::numeric) = 0::numeric THEN NULL::numeric
            ELSE round((COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric)) / NULLIF(a."PUArticle", 0::numeric) * 100::numeric, 2)
        END AS "TauxMargePct",
    a."DatePeremptionArticle",
    a."DatePeremptionAlerteArticle",
    a."NbreJoursAlerteArticle",
        CASE
            WHEN a."DatePeremptionArticle" IS NULL THEN 'Non renseignée'::text
            WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 'Périmé'::text
            WHEN a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE THEN 'Alerte péremption'::text
            WHEN a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle") THEN 'Alerte péremption'::text
            ELSE 'Valide'::text
        END AS "EtatPeremption",
        CASE
            WHEN a."DatePeremptionArticle" IS NOT NULL THEN a."DatePeremptionArticle"::date - CURRENT_DATE
            ELSE NULL::integer
        END AS "JoursAvantPeremption",
    a."DatePeremptionArticle" IS NOT NULL AND a."DatePeremptionArticle"::date < CURRENT_DATE AS "EstPerime",
    a."DatePeremptionArticle" IS NOT NULL AND a."DatePeremptionArticle"::date >= CURRENT_DATE AND (a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE OR a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle")) AS "EstAlertePeremption",
        CASE
            WHEN a."DatePeremptionArticle" IS NULL THEN 4
            WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 1
            WHEN a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE OR a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle") THEN 2
            ELSE 3
        END AS "PrioritePeremption",
    a."ID_UserFK",
    u."IdUser",
    NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text) AS "NomComplet",
        CASE
            WHEN COALESCE(a."ValideArticle", true) = false THEN 'Inactif'::text
            ELSE 'Actif'::text
        END AS "EtatArticle" ,
 a."PoidsUnitaire",a."ID_UnitePoidsFk",
 (SELECT g."AbrGenerique" FROM referentiel."T_Generique" g WHERE g."ID_Generique"=a."ID_UnitePoidsFk") AS "UnitePoids",
 (SELECT count(*)::integer FROM logistique."T_LotArticle" l WHERE l."ID_ArticleFk"=a."ID_Article") AS "NombreLots",
 (SELECT COALESCE(sum(l."StockLot"),0)::numeric FROM logistique."V_LotArticleStock" l WHERE l."ID_ArticleFk"=a."ID_Article") AS "StockVentileLots",
 (a."QteArticle"-(SELECT COALESCE(sum(l."StockLot"),0) FROM logistique."V_LotArticleStock" l WHERE l."ID_ArticleFk"=a."ID_Article"))::numeric AS "StockSansLot",a."InformationArticle"

   FROM logistique."T_Article" a
     LEFT JOIN referentiel."T_Generique" type_article ON a."ID_TypeArticleFk" = type_article."ID_Generique" AND type_article."ID_CategorieGeneriqueFk" = 46
     LEFT JOIN referentiel."T_Generique" categorie_article ON a."ID_CategorieArticleFk" = categorie_article."ID_Generique" AND categorie_article."ID_CategorieGeneriqueFk" = 40
     LEFT JOIN referentiel."T_Generique" unite ON a."ID_UniteFk" = unite."ID_Generique" AND unite."ID_CategorieGeneriqueFk" = 34
     LEFT JOIN systeme."T_Utilisateurs" u ON a."ID_UserFK" = u."IdUser";
COMMENT ON COLUMN logistique."V_Article"."InformationArticle" IS 'Description et caractéristiques complémentaires du produit, distinctes des observations.';
COMMENT ON COLUMN logistique."V_Article"."PoidsUnitaire" IS 'Masse d’une unité de stock, inconnue si NULL.';
COMMENT ON COLUMN logistique."V_Article"."ID_UnitePoidsFk" IS 'Unité de masse du poids unitaire.';
COMMENT ON COLUMN logistique."V_Article"."UnitePoids" IS 'Abréviation de l’unité de masse du référentiel.';
COMMENT ON COLUMN logistique."V_Article"."NombreLots" IS 'Nombre de numéros de lot connus pour cet article, actifs ou archivés.';
COMMENT ON COLUMN logistique."V_Article"."StockVentileLots" IS 'Stock courant identifié par numéro de lot, issu des mouvements ventilés.';
COMMENT ON COLUMN logistique."V_Article"."StockSansLot" IS 'Part du stock global encore dépourvue de numéro de lot ; aucune attribution inventée.';
COMMIT;
