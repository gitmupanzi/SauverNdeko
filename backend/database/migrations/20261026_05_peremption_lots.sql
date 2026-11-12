-- Péremption exhaustive du stock restant, seuils d’entreprise et dérogations auditées.
-- Aucun stock ni mouvement supplémentaire ; défaut informatif conservé.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base hors périmètre'; END IF;
 IF to_regclass('logistique."V_ArticlePeremption"') IS NOT NULL THEN RAISE EXCEPTION 'Migration péremption déjà installée'; END IF;
END $$;
ALTER TABLE systeme."T_Entite" ADD COLUMN "AlertePeremptionJours" smallint NOT NULL DEFAULT 30 CHECK("AlertePeremptionJours" BETWEEN 0 AND 3650), ADD COLUMN "BloquerLotsPerimes" boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN systeme."T_Entite"."AlertePeremptionJours" IS 'Délai d’alerte par défaut de cette entreprise, en jours ; le seuil explicite de l’article prime.';
COMMENT ON COLUMN systeme."T_Entite"."BloquerLotsPerimes" IS 'Refuse les nouveaux prélèvements sur des lots périmés, sauf dérogation motivée d’un administrateur global ; false conserve le mode informatif.';
ALTER TABLE logistique."T_MouvementLot" ADD COLUMN "MotifDerogationPeremption" text, ADD COLUMN "ID_DerogationUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT, ADD COLUMN "DateDerogationPeremption" timestamptz;
ALTER TABLE logistique."T_MouvementLot" ADD CONSTRAINT mouvement_lot_derogation_complete CHECK(("MotifDerogationPeremption" IS NULL AND "ID_DerogationUserFk" IS NULL AND "DateDerogationPeremption" IS NULL) OR ("MotifDerogationPeremption" IS NOT NULL AND length(btrim("MotifDerogationPeremption")) BETWEEN 10 AND 1000 AND "ID_DerogationUserFk" IS NOT NULL AND "DateDerogationPeremption" IS NOT NULL));
COMMENT ON COLUMN logistique."T_MouvementLot"."MotifDerogationPeremption" IS 'Justification explicite d’un prélèvement périmé, conservée avec sa ventilation historique ; aucun effet de stock supplémentaire.';
COMMENT ON COLUMN logistique."T_MouvementLot"."ID_DerogationUserFk" IS 'Compte global autorisant le prélèvement périmé ; distinct de l’auteur initial du bon.';
COMMENT ON COLUMN logistique."T_MouvementLot"."DateDerogationPeremption" IS 'Horodatage serveur de la dérogation de péremption.';
CREATE FUNCTION logistique.controler_sortie_lot_perime() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE s integer; expiration date; bloque boolean; BEGIN
 IF TG_OP='UPDATE' AND NEW IS NOT DISTINCT FROM OLD THEN RETURN NEW; END IF;
 SELECT v."SigneStock",l."DatePeremptionLot",e."BloquerLotsPerimes" INTO s,expiration,bloque
 FROM logistique."T_Mouvement" m JOIN logistique."V_MouvementStock" v ON v."ID_Mvt"=m."ID_Mvt"
 JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=NEW."ID_LotArticleFk"
 JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk" JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk"
 WHERE m."ID_Mvt"=NEW."ID_MvtFk";
 IF NEW."MotifDerogationPeremption" IS NOT NULL THEN
  IF s<>-1 OR expiration IS NULL OR expiration>=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date OR NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_DerogationUserFk" AND "ValideUser" IS TRUE AND "Is_Admin" IS TRUE) THEN
   RAISE EXCEPTION 'Dérogation de péremption réservée à un administrateur global actif et à un lot périmé sortant' USING ERRCODE='23514'; END IF;
  NEW."MotifDerogationPeremption"=btrim(NEW."MotifDerogationPeremption");
  NEW."DateDerogationPeremption"=clock_timestamp();
 ELSIF s=-1 AND expiration<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AND bloque IS TRUE THEN
  RAISE EXCEPTION 'Lot périmé : sortie bloquée ; dérogation motivée requise' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER peremption_lot_sortie BEFORE INSERT OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.controler_sortie_lot_perime();
COMMENT ON FUNCTION logistique.controler_sortie_lot_perime() IS 'Défense SQL des prélèvements sur lots périmés selon l’entreprise ; contrôle l’auteur global et conserve le motif sur la ventilation.';
COMMENT ON TRIGGER peremption_lot_sortie ON logistique."T_MouvementLot" IS 'Applique la politique de péremption uniquement aux nouveaux prélèvements ou aux modifications de ventilation.';
DO $$ DECLARE def text; BEGIN
 SELECT pg_get_viewdef('logistique."V_LotArticleStock"'::regclass,true) INTO def;
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_LotArticleStock" AS SELECT l.*,
 CASE WHEN l."DatePeremptionLot" IS NULL THEN ''Non renseignée'' WHEN l."DatePeremptionLot"<(CURRENT_TIMESTAMP AT TIME ZONE ''Africa/Kinshasa'')::date THEN ''Périmé'' WHEN l."DatePeremptionLot"<=(CURRENT_TIMESTAMP AT TIME ZONE ''Africa/Kinshasa'')::date+COALESCE(a."NbreJoursAlerteArticle",e."AlertePeremptionJours",30) THEN ''Proche'' ELSE ''Valide'' END::text AS "EtatPeremptionLot",
 (l."DatePeremptionLot"<(CURRENT_TIMESTAMP AT TIME ZONE ''Africa/Kinshasa'')::date) IS TRUE AS "EstPerime",(l."DatePeremptionLot" BETWEEN (CURRENT_TIMESTAMP AT TIME ZONE ''Africa/Kinshasa'')::date AND (CURRENT_TIMESTAMP AT TIME ZONE ''Africa/Kinshasa'')::date+COALESCE(a."NbreJoursAlerteArticle",e."AlertePeremptionJours",30)) IS TRUE AS "EstProche",
 COALESCE(a."NbreJoursAlerteArticle",e."AlertePeremptionJours",30) AS "SeuilAlerteJours",e."BloquerLotsPerimes"
 FROM ('||rtrim(def,'; '||chr(10))||') l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk" LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk"';
 SELECT pg_get_viewdef('logistique."V_MouvementLot"'::regclass,true) INTO def;
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_MouvementLot" AS SELECT l.*,ml."MotifDerogationPeremption",ml."ID_DerogationUserFk",ml."DateDerogationPeremption" FROM ('||rtrim(def,'; '||chr(10))||') l JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=l."ID_MvtFk" AND ml."ID_LotArticleFk"=l."ID_LotArticleFk"';
END $$;
COMMENT ON VIEW logistique."V_LotArticleStock" IS 'Stock restant par lot avec conservation et politique d’entreprise ; l’état d’un lot épuisé reste historique et ne déclenche pas une alerte Article.';
COMMENT ON VIEW logistique."V_MouvementLot" IS 'Historique des ventilations avec motif, compte et date de la dérogation de péremption éventuelle ; aucun mouvement supplémentaire.';
CREATE OR REPLACE VIEW logistique."V_LotDisponibilite" AS
 SELECT l."ID_LotArticle",l."ID_ArticleFk",l."NumeroLot",l."DatePeremptionLot",l."Actif",l."CreeLe",l."StockLot",l."QuantiteEntree",l."QuantiteSortie",l."ID_DeviseFk",l."DeviseCode",l."DeviseLibelle",a."IdEntiteFk",a."NomArticle",a."ID_UniteFk",u."AbrGenerique" AS "Unite",
 CASE WHEN l."DatePeremptionLot" IS NULL THEN 'Non renseignée' WHEN l."DatePeremptionLot"<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date THEN 'Périmé'
 WHEN l."DatePeremptionLot"<=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date+COALESCE(a."NbreJoursAlerteArticle",e."AlertePeremptionJours",30) THEN 'Proche' ELSE 'Valide' END AS "EtatPeremptionLot",
 (l."DatePeremptionLot"<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date) IS TRUE AS "EstPerime",
 (l."DatePeremptionLot" BETWEEN (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AND (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date+COALESCE(a."NbreJoursAlerteArticle",e."AlertePeremptionJours",30)) IS TRUE AS "EstProche",
 COALESCE(a."NbreJoursAlerteArticle",e."AlertePeremptionJours",30) AS "SeuilAlerteJours",e."BloquerLotsPerimes"
 FROM logistique."V_LotArticleStock" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
 LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk" LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk";
COMMENT ON VIEW logistique."V_LotDisponibilite" IS 'Stock réel par lot, seuil article ou entreprise, état de péremption et politique de sortie ; un lot épuisé conserve son historique.';
CREATE VIEW logistique."V_ArticlePeremption" AS
 WITH lots AS (
 SELECT "ID_ArticleFk",sum("StockLot") AS total,
 COALESCE(sum("StockLot") FILTER(WHERE "StockLot">0 AND "EstPerime"),0) AS perime,
 COALESCE(sum("StockLot") FILTER(WHERE "StockLot">0 AND "EstProche"),0) AS proche,
 COALESCE(sum("StockLot") FILTER(WHERE "StockLot">0 AND "DatePeremptionLot" IS NULL),0) AS sansdate,
 min("DatePeremptionLot") FILTER(WHERE "StockLot">0) AS dateproche,
 count(*) FILTER(WHERE "StockLot">0 AND "EstPerime") AS lotsperimes,
 count(*) FILTER(WHERE "StockLot">0 AND "EstProche") AS lotsproches
 FROM logistique."V_LotDisponibilite" GROUP BY "ID_ArticleFk"
 ), stocks AS (
 SELECT a."ID_Article",a."IdEntiteFk",a."QteArticle",a."DatePeremptionArticle"::date AS generale,
 a."DatePeremptionAlerteArticle"::date AS alertegenerale,
 COALESCE(a."NbreJoursAlerteArticle",e."AlertePeremptionJours",30) AS seuil,
 GREATEST(COALESCE(a."QteArticle",0)-COALESCE(l.total,0),0) AS sanslot,
 COALESCE(l.perime,0) AS lotperime,COALESCE(l.proche,0) AS lotproche,COALESCE(l.sansdate,0) AS lotsansdate,
 l.dateproche,COALESCE(l.lotsperimes,0) AS lotsperimes,COALESCE(l.lotsproches,0) AS lotsproches
 FROM logistique."T_Article" a LEFT JOIN lots l ON l."ID_ArticleFk"=a."ID_Article" LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk"
 ), classement AS (
 SELECT *,lotperime+CASE WHEN generale<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date THEN sanslot ELSE 0 END AS perime,
 lotproche+CASE WHEN generale>=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AND (generale<=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date+seuil OR alertegenerale<=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date) THEN sanslot ELSE 0 END AS proche,
 lotsansdate+CASE WHEN generale IS NULL THEN sanslot ELSE 0 END AS sansdate,
 LEAST(dateproche,CASE WHEN sanslot>0 THEN generale END) AS prochaine
 FROM stocks)
 SELECT "ID_Article","IdEntiteFk",perime::numeric AS "StockPerime",proche::numeric AS "StockProchePeremption",sansdate::numeric AS "StockSansDatePeremption",sanslot::numeric AS "StockSansLot",
 prochaine AS "DateProchainePeremption",lotsperimes AS "LotsPerimes",lotsproches AS "LotsProchesPeremption",seuil AS "SeuilAlerteJours",
 perime>0 AS "EstPerime",proche>0 AS "EstAlertePeremption",
 CASE WHEN perime>0 THEN 'Périmé' WHEN proche>0 THEN 'Alerte péremption' WHEN COALESCE("QteArticle",0)<=0 THEN 'Sans stock' WHEN sansdate>0 THEN 'Non renseignée' ELSE 'Valide' END::text AS "EtatPeremption",
 prochaine-(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AS "JoursAvantPeremption",
 CASE WHEN perime>0 THEN 1 WHEN proche>0 THEN 2 WHEN sansdate>0 OR COALESCE("QteArticle",0)<=0 THEN 4 ELSE 3 END AS "PrioritePeremption"
 FROM classement;
COMMENT ON VIEW logistique."V_ArticlePeremption" IS 'Situation exhaustive de conservation : uniquement les quantités encore en stock, tous lots y compris archivés, et le stock sans lot couvert par la date générale. Une même référence peut avoir simultanément du stock périmé et proche.';
DO $$ DECLARE def text; cols text; BEGIN
 SELECT pg_get_viewdef('logistique."V_Article"'::regclass,true) INTO def;
 SELECT string_agg(CASE WHEN attname IN ('EstPerime','EstAlertePeremption','EtatPeremption','JoursAvantPeremption','PrioritePeremption') THEN format('p.%I',attname) ELSE format('source.%I',attname) END,',' ORDER BY attnum) INTO cols
 FROM pg_attribute WHERE attrelid='logistique."V_Article"'::regclass AND attnum>0 AND NOT attisdropped;
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_Article" AS SELECT '||cols||',p."StockPerime",p."StockProchePeremption",p."StockSansDatePeremption",p."DateProchainePeremption",p."LotsPerimes",p."LotsProchesPeremption",p."SeuilAlerteJours" FROM ('||rtrim(def,'; '||chr(10))||') source JOIN logistique."V_ArticlePeremption" p ON p."ID_Article"=source."ID_Article"';
END $$;
COMMENT ON VIEW logistique."V_Article" IS 'Catalogue partagé avec stock et conservation exhaustifs par lots restants et stock sans lot ; les prix catalogue ne constituent pas un coût moyen comptable.';
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name IN ('V_ArticlePeremption','V_LotDisponibilite','V_LotArticleStock','V_MouvementLot') LOOP
 EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',r.table_name,r.column_name,'Conservation du stock : '||r.column_name||', calculée dans le périmètre de l’article et de son entreprise.'); END LOOP;
 FOR r IN SELECT column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name='V_Article' AND column_name IN ('EstPerime','EstAlertePeremption','EtatPeremption','JoursAvantPeremption','PrioritePeremption','StockPerime','StockProchePeremption','StockSansDatePeremption','DateProchainePeremption','LotsPerimes','LotsProchesPeremption','SeuilAlerteJours') LOOP
 EXECUTE format('COMMENT ON COLUMN logistique."V_Article".%I IS %L',r.column_name,'Conservation exhaustive du stock restant par lot et du stock sans lot : '||r.column_name||'.'); END LOOP;
END $$;
COMMIT;
