-- Quantités exactes, politique explicite par unité et inventaires physiques.
-- Prérequis09 : propriété IdEntiteFk immuable sur Article et Commande.
-- Aucun comptage ni ajustement créé lors de l'installation.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base hors périmètre'; END IF;
 IF NOT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='logistique' AND table_name='T_Article' AND column_name='IdEntiteFk') THEN RAISE EXCEPTION 'Migration09 requise'; END IF;
 IF to_regclass('logistique."T_Inventaire"') IS NOT NULL THEN RAISE EXCEPTION 'Migration10 déjà installée'; END IF;
END $$;
LOCK TABLE logistique."T_Article",logistique."T_Commande",logistique."T_CommandeDetail",logistique."T_Mouvement",logistique."T_MouvementLot",logistique."T_FactureLigne" IN ACCESS EXCLUSIVE MODE;

-- Sauvegarder le graphe des vues dépendantes, commentaires, propriétaire et ACL.
-- DROP RESTRICT refuse une dépendance inconnue (aucun CASCADE destructeur).
CREATE TEMP TABLE qty_views ON COMMIT DROP AS
 WITH RECURSIVE affected(oid,depth,path) AS (
  SELECT c.oid,0,ARRAY[c.oid] FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='logistique' AND c.relname IN ('T_Article','T_Mouvement','T_MouvementLot','T_FactureLigne')
  UNION ALL SELECT c.oid,a.depth+1,a.path||c.oid FROM affected a JOIN pg_depend d ON d.refobjid=a.oid
  JOIN pg_rewrite r ON r.oid=d.objid JOIN pg_class c ON c.oid=r.ev_class
  WHERE c.oid<>ALL(a.path) AND c.relkind IN ('v','m')
 ) SELECT c.oid,n.nspname schema,c.relname name,max(a.depth) depth,c.relkind,
 pg_get_viewdef(c.oid,true) definition,pg_get_userbyid(c.relowner) owner,c.reloptions,
 obj_description(c.oid,'pg_class') description,c.relacl
 FROM affected a JOIN pg_class c ON c.oid=a.oid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind IN ('v','m') GROUP BY c.oid,n.nspname,c.relname;
CREATE TEMP TABLE qty_columns ON COMMIT DROP AS
 SELECT v.oid,a.attname,col_description(v.oid,a.attnum) description,a.attacl FROM qty_views v JOIN pg_attribute a ON a.attrelid=v.oid WHERE a.attnum>0 AND NOT a.attisdropped;
DO $$ DECLARE v record; BEGIN
 IF EXISTS(SELECT FROM qty_views WHERE relkind<>'v') THEN RAISE EXCEPTION 'Vue matérialisée dépendante : revue dédiée requise'; END IF;
 IF EXISTS(SELECT FROM qty_views x JOIN pg_trigger t ON t.tgrelid=x.oid WHERE NOT t.tgisinternal) OR
    EXISTS(SELECT FROM qty_views x JOIN pg_rewrite r ON r.ev_class=x.oid WHERE r.rulename<>'_RETURN') THEN RAISE EXCEPTION 'Vue à règle métier : revue dédiée requise'; END IF;
 FOR v IN SELECT * FROM qty_views ORDER BY depth DESC LOOP EXECUTE format('DROP VIEW %I.%I RESTRICT',v.schema,v.name); END LOOP;
END $$;
ALTER TABLE logistique."T_Article" ALTER COLUMN "QteMinArticle" TYPE numeric(14,3);
ALTER TABLE logistique."T_Mouvement" ALTER COLUMN "QteMvt" TYPE numeric(14,3);
ALTER TABLE logistique."T_MouvementLot" ALTER COLUMN "Quantite" TYPE numeric(14,3);
ALTER TABLE logistique."T_FactureLigne" ALTER COLUMN "QteSortie" TYPE numeric(14,3), ALTER COLUMN "QteRetourAvantFacture" TYPE numeric(14,3), ALTER COLUMN "QteFacturee" TYPE numeric(14,3);
DO $$ DECLARE v record; c record; acl record; def text; BEGIN
 FOR v IN SELECT * FROM qty_views ORDER BY depth LOOP
  def=v.definition;
  def=replace(def,'COALESCE(cd."QteCmdDetail", 0::numeric) * COALESCE(cd."PUCmdDetail", 0::numeric)','round(COALESCE(cd."QteCmdDetail", 0::numeric) * COALESCE(cd."PUCmdDetail", 0::numeric),2)');
  IF v.name='V_RetourArticle' THEN
   def=regexp_replace(def,' AND d\."QteCmdDetail" = trunc\(d\."QteCmdDetail"\)','','g');
  END IF;
  EXECUTE format('CREATE VIEW %I.%I AS %s',v.schema,v.name,def);
  IF v.reloptions IS NOT NULL THEN EXECUTE format('ALTER VIEW %I.%I SET (%s)',v.schema,v.name,array_to_string(v.reloptions,',')); END IF;
  EXECUTE format('COMMENT ON VIEW %I.%I IS %L',v.schema,v.name,v.description);
  FOR c IN SELECT * FROM qty_columns WHERE oid=v.oid LOOP
   EXECUTE format('COMMENT ON COLUMN %I.%I.%I IS %L',v.schema,v.name,c.attname,c.description);
  END LOOP;
  FOR acl IN SELECT x.*,CASE WHEN grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(grantee)) END recipient FROM aclexplode(v.relacl) x LOOP
   EXECUTE format('GRANT %s ON %I.%I TO %s%s',acl.privilege_type,v.schema,v.name,acl.recipient,CASE WHEN acl.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
  END LOOP;
  FOR c IN SELECT * FROM qty_columns WHERE oid=v.oid AND attacl IS NOT NULL LOOP
   FOR acl IN SELECT x.*,CASE WHEN grantee=0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(grantee)) END recipient FROM aclexplode(c.attacl) x LOOP
    EXECUTE format('GRANT %s(%I) ON %I.%I TO %s%s',acl.privilege_type,c.attname,v.schema,v.name,acl.recipient,CASE WHEN acl.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
   END LOOP;
  END LOOP;
  EXECUTE format('ALTER VIEW %I.%I OWNER TO %I',v.schema,v.name,v.owner);
 END LOOP;
END $$;

-- Une unité non configurée reste discrète. Aucune déduction depuis son nom.
CREATE TABLE logistique."T_UniteStockPrecision"(
 "ID_UniteFk" integer PRIMARY KEY REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "Decimales" smallint NOT NULL DEFAULT 0 CHECK("Decimales" BETWEEN 0 AND 3),
 "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE FUNCTION logistique.verifier_precision_unite() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Modifiez la précision explicitement au lieu de supprimer sa politique' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."ID_UniteFk" AND "ID_CategorieGeneriqueFk"=34) THEN RAISE EXCEPTION 'Unité de stock requise' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' AND NEW."ID_UniteFk"<>OLD."ID_UniteFk" THEN RAISE EXCEPTION 'Unité immuable' USING ERRCODE='23514'; END IF;
 IF EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_UniteFk"=NEW."ID_UniteFk" AND
  (a."QteArticle"<>round(a."QteArticle",NEW."Decimales") OR a."QteMinArticle"<>round(a."QteMinArticle",NEW."Decimales"))) OR
 EXISTS(SELECT FROM logistique."T_Mouvement" m JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE a."ID_UniteFk"=NEW."ID_UniteFk" AND m."QteMvt"<>round(m."QteMvt",NEW."Decimales")) OR
 EXISTS(SELECT FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk" JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE a."ID_UniteFk"=NEW."ID_UniteFk" AND ml."Quantite"<>round(ml."Quantite",NEW."Decimales")) THEN
 RAISE EXCEPTION 'La précision est incompatible avec les quantités historiques' USING ERRCODE='23514'; END IF;
 NEW."ModifieLe"=clock_timestamp();RETURN NEW;
END $$;
CREATE TRIGGER precision_unite_integrite BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_UniteStockPrecision" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_precision_unite();
CREATE FUNCTION logistique.fn_verifier_quantite(p_unite integer,p_qte numeric) RETURNS void LANGUAGE plpgsql AS $$ DECLARE d integer; BEGIN
 IF p_qte IS NULL THEN RETURN; END IF;
 IF p_qte<0 OR p_qte::text IN ('NaN','Infinity','-Infinity') OR p_qte>99999999999.999 OR p_qte<>round(p_qte,3) THEN RAISE EXCEPTION 'Quantité hors précision' USING ERRCODE='23514';END IF;
 PERFORM 1 FROM logistique."T_UniteStockPrecision" WHERE "ID_UniteFk"=p_unite FOR SHARE;
 SELECT COALESCE(p."Decimales",0) INTO d FROM referentiel."T_Generique" g LEFT JOIN logistique."T_UniteStockPrecision" p ON p."ID_UniteFk"=g."ID_Generique" WHERE g."ID_Generique"=p_unite AND g."ID_CategorieGeneriqueFk"=34;
 IF d IS NULL OR p_qte<>round(p_qte,d) THEN RAISE EXCEPTION 'Quantité incompatible avec la précision de son unité' USING ERRCODE='23514';END IF;
END $$;
CREATE FUNCTION logistique.tr_quantite_unite() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE u integer; BEGIN
 IF TG_TABLE_NAME='T_Article' THEN u=NEW."ID_UniteFk";PERFORM logistique.fn_verifier_quantite(u,NEW."QteArticle");PERFORM logistique.fn_verifier_quantite(u,NEW."QteMinArticle");
 ELSIF TG_TABLE_NAME='T_CommandeDetail' THEN SELECT "ID_UniteFk" INTO u FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk";PERFORM logistique.fn_verifier_quantite(u,NEW."QteCmdDetail");
 ELSIF TG_TABLE_NAME='T_Mouvement' THEN SELECT "ID_UniteFk" INTO u FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk";PERFORM logistique.fn_verifier_quantite(u,NEW."QteMvt");
 ELSE SELECT a."ID_UniteFk" INTO u FROM logistique."T_Mouvement" m JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE m."ID_Mvt"=NEW."ID_MvtFk";PERFORM logistique.fn_verifier_quantite(u,NEW."Quantite");END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER quantite_unite_article BEFORE INSERT OR UPDATE OF "QteArticle","QteMinArticle","ID_UniteFk" ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_quantite_unite();
CREATE TRIGGER quantite_unite_ligne BEFORE INSERT OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_quantite_unite();
CREATE TRIGGER quantite_unite_mouvement BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_quantite_unite();
CREATE TRIGGER quantite_unite_lot BEFORE INSERT OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.tr_quantite_unite();

-- Adapter les fonctions réellement installées, conserver les protections09 sans les écraser.
DO $$ DECLARE id oid; def text; old_def text; BEGIN
 SELECT oid INTO STRICT id FROM pg_proc WHERE pronamespace='logistique'::regnamespace AND proname='ps_crud_commandedetail';
 def=pg_get_functiondef(id);old_def=def;
 def=replace(def,' OR p_old_qte<>trunc(p_old_qte)','');def=replace(def,' OR p_new_qte<>trunc(p_new_qte)','');
 def=replace(def,'p_new_qte::integer','p_new_qte');
 IF def=old_def OR position('p_new_qte::integer' in def)>0 THEN RAISE EXCEPTION 'Procédure quantité inattendue';END IF;
 EXECUTE def;
 SELECT oid INTO STRICT id FROM pg_proc WHERE pronamespace='logistique'::regnamespace AND proname='tr_crud_article_after';
 def=pg_get_functiondef(id);
 def=regexp_replace(def,'IF v_new_qte <> trunc\(v_new_qte\) THEN RAISE EXCEPTION[^;]+;\s*END IF;','','g');
 def=regexp_replace(def,'IF abs\(v_delta\) <> trunc\(abs\(v_delta\)\) THEN RAISE EXCEPTION[^;]+;\s*END IF;','','g');
 def=replace(def,'v_qte_mvt integer','v_qte_mvt numeric(14,3)');
 def=replace(replace(replace(def,'v_new_qte::integer','v_new_qte'),'v_delta::integer','v_delta'),'abs(v_delta)::integer','abs(v_delta)');
 IF position('trunc(' in def)>0 OR position('v_qte_mvt integer' in def)>0 THEN RAISE EXCEPTION 'Trigger quantité inattendu';END IF;
 EXECUTE def;
 SELECT oid INTO STRICT id FROM pg_proc WHERE pronamespace='logistique'::regnamespace AND proname='controler_retour_bon';
 def=replace(pg_get_functiondef(id),' OR candidat."QteCmdDetail"<>trunc(candidat."QteCmdDetail")','');
 def=replace(def,'sum("QteCmdDetail"*"PUCmdDetail")','sum(round("QteCmdDetail"*"PUCmdDetail",2))');
 IF position('trunc(' in def)>0 THEN RAISE EXCEPTION 'Contrôle retour quantité inattendu';END IF;EXECUTE def;
 SELECT oid INTO STRICT id FROM pg_proc WHERE pronamespace='logistique'::regnamespace AND proname='ps_update_totaux_commande';
 def=replace(pg_get_functiondef(id),'COALESCE(d."QteCmdDetail",0) * COALESCE(d."PUCmdDetail",0)','round(COALESCE(d."QteCmdDetail",0) * COALESCE(d."PUCmdDetail",0),2)');EXECUTE def;
END $$;
-- Le montant d'une ligne est arrondi avant sommation, comme son instantané de facture.
DO $$ DECLARE c record; BEGIN
 FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='logistique."T_FactureLigne"'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%MontantLigne%' LOOP EXECUTE format('ALTER TABLE logistique."T_FactureLigne" DROP CONSTRAINT %I',c.conname); END LOOP;
END $$;
ALTER TABLE logistique."T_FactureLigne" ADD CONSTRAINT facture_ligne_montant_arrondi CHECK("MontantLigne"=round("QteFacturee"*"PUFacture",2));

CREATE TABLE logistique."T_Inventaire"(
 "ID_Inventaire" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "DateInventaire" timestamptz NOT NULL,"Motif" text NOT NULL CHECK(length(btrim("Motif")) BETWEEN 1 AND 1000),
 "Etat" text NOT NULL DEFAULT 'brouillon' CHECK("Etat" IN ('brouillon','valide')),
 "Version" bigint NOT NULL DEFAULT 1,"CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),"ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "ValideLe" timestamptz,"ID_ValidateurFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "ValidationRequest" uuid,"ValidationHash" text,
 CHECK(("Etat"='valide')=("ValideLe" IS NOT NULL AND "ID_ValidateurFk" IS NOT NULL AND "ValidationRequest" IS NOT NULL AND "ValidationHash" IS NOT NULL))
);
CREATE INDEX inventaire_entite_date ON logistique."T_Inventaire"("IdEntiteFk","DateInventaire" DESC);
CREATE TABLE logistique."T_InventaireLigne"(
 "ID_InventaireFk" bigint NOT NULL REFERENCES logistique."T_Inventaire"("ID_Inventaire") ON DELETE RESTRICT,
 "ID_ArticleFk" integer NOT NULL REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 "QteTheorique" numeric(14,3) NOT NULL CHECK("QteTheorique">=0),
 "QteComptee" numeric(14,3) NOT NULL CHECK("QteComptee">=0),
 "PUCorrection" numeric(12,2) CHECK("PUCorrection">=0),
 "Lots" jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof("Lots")='array'),
 "Justification" text NOT NULL CHECK(length(btrim("Justification")) BETWEEN 1 AND 1000),
 "ID_CommandeCorrectionFk" integer REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT,
 PRIMARY KEY("ID_InventaireFk","ID_ArticleFk")
);
CREATE FUNCTION logistique.verifier_inventaire() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE h record; a record; BEGIN
 IF TG_TABLE_NAME='T_Inventaire' THEN
  IF TG_OP='DELETE' OR TG_OP='UPDATE' AND (OLD."Etat"='valide' OR OLD."IdEntiteFk"<>NEW."IdEntiteFk" OR OLD."ID_UserFk"<>NEW."ID_UserFk") THEN RAISE EXCEPTION 'Inventaire historique ou propriétaire immuable' USING ERRCODE='23514';END IF;
  IF TG_OP='UPDATE' THEN NEW."Version"=OLD."Version"+1;NEW."ModifieLe"=clock_timestamp();END IF;RETURN NEW;
 END IF;
 SELECT * INTO h FROM logistique."T_Inventaire" WHERE "ID_Inventaire"=COALESCE(NEW."ID_InventaireFk",OLD."ID_InventaireFk") FOR UPDATE;
 IF h."Etat"<>'brouillon' THEN RAISE EXCEPTION 'Un inventaire validé est conservé' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
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
CREATE TRIGGER inventaire_integrite BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Inventaire" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_inventaire();
CREATE TRIGGER inventaire_ligne_integrite BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_InventaireLigne" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_inventaire();
CREATE FUNCTION logistique.controler_inventaire_valide() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF NEW."Etat"='valide' AND (NOT EXISTS(SELECT FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=NEW."ID_Inventaire") OR
  EXISTS(SELECT FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=NEW."ID_Inventaire" AND ("QteComptee"<>"QteTheorique")<>("ID_CommandeCorrectionFk" IS NOT NULL))) THEN
 RAISE EXCEPTION 'Chaque écart doit posséder son bon correcteur unique' USING ERRCODE='23514';END IF;RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER inventaire_validation_complete AFTER INSERT OR UPDATE ON logistique."T_Inventaire" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_inventaire_valide();
CREATE FUNCTION logistique.proteger_bon_inventaire() RETURNS trigger LANGUAGE plpgsql AS $$ DECLARE target integer; BEGIN
 IF TG_TABLE_NAME='T_Commande' THEN target=OLD."ID_Commande";
 ELSIF TG_TABLE_NAME='T_CommandeDetail' THEN target=COALESCE(NEW."ID_CmdFk",OLD."ID_CmdFk");
 ELSE target=COALESCE(NEW."ID_cmdFk",OLD."ID_cmdFk");END IF;
 IF EXISTS(SELECT FROM logistique."T_InventaireLigne" l JOIN logistique."T_Inventaire" h ON h."ID_Inventaire"=l."ID_InventaireFk" WHERE l."ID_CommandeCorrectionFk"=target AND h."Etat"='valide') THEN
 RAISE EXCEPTION 'Un bon d’inventaire validé est conservé ; créez un nouveau comptage correcteur' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;
CREATE TRIGGER aa_inventaire_bon_protection BEFORE UPDATE OR DELETE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_inventaire();
CREATE TRIGGER aa_inventaire_ligne_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_inventaire();
CREATE TRIGGER aa_inventaire_mouvement_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_inventaire();
CREATE VIEW logistique."V_Inventaire" AS SELECT h.*, 'inv-'||h."ID_Inventaire" AS "CodeInventaire",count(l."ID_ArticleFk") AS "NbArticles",count(*) FILTER(WHERE l."QteComptee"<>l."QteTheorique") AS "NbEcarts" FROM logistique."T_Inventaire" h LEFT JOIN logistique."T_InventaireLigne" l ON l."ID_InventaireFk"=h."ID_Inventaire" GROUP BY h."ID_Inventaire";
CREATE VIEW logistique."V_InventaireLigne" AS SELECT l.*,l."QteComptee"-l."QteTheorique" AS "Ecart",a."IdEntiteFk",a."NomArticle",a."CodeArticleInterne",a."ID_UniteFk",g."AbrGenerique" AS "Unite",a."QteArticle" AS "StockActuel",COALESCE(p."Decimales",0) AS "Decimales",c."CodeCmd" AS "CodeCorrection" FROM logistique."T_InventaireLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk" LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=a."ID_UniteFk" LEFT JOIN logistique."T_UniteStockPrecision" p ON p."ID_UniteFk"=a."ID_UniteFk" LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=l."ID_CommandeCorrectionFk";
CREATE VIEW logistique."V_LotDisponibilite" AS SELECT l.*,a."IdEntiteFk",a."NomArticle",a."ID_UniteFk",u."AbrGenerique" AS "Unite",
 CASE WHEN l."DatePeremptionLot" IS NULL THEN 'Non renseignée' WHEN l."DatePeremptionLot"<CURRENT_DATE THEN 'Périmé' WHEN l."DatePeremptionLot"<=CURRENT_DATE+30 THEN 'Proche' ELSE 'Valide' END AS "EtatPeremptionLot",
 (l."DatePeremptionLot"<CURRENT_DATE) IS TRUE AS "EstPerime",(l."DatePeremptionLot" BETWEEN CURRENT_DATE AND CURRENT_DATE+30) IS TRUE AS "EstProche"
 FROM logistique."V_LotArticleStock" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk" LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk";

COMMENT ON TABLE logistique."T_UniteStockPrecision" IS 'Politique partagée explicite de précision des quantités par unité du référentiel ; absence équivaut à zéro décimale, sans heuristique de nom.';
COMMENT ON TABLE logistique."T_Inventaire" IS 'Comptage physique versionné par entreprise ; validation justifiée et bons compensateurs, sans effacer le journal des mouvements.';
COMMENT ON TABLE logistique."T_InventaireLigne" IS 'Stock théorique au comptage, quantité comptée et lots du seul écart ; chaque écart non nul est relié à une ligne de bon correcteur.';
COMMENT ON VIEW logistique."V_Inventaire" IS 'Registre des comptages physiques et nombre de lignes présentant un écart ; aucune somme entre unités différentes.';
COMMENT ON VIEW logistique."V_InventaireLigne" IS 'Comparaison exacte du comptage et du stock, unité explicite, propriétaire stable et lien au bon correcteur.';
COMMENT ON VIEW logistique."V_LotDisponibilite" IS 'Disponibilité réelle par lot et alerte de péremption ; les 30 jours de proximité sont informatifs, FEFO reste une proposition explicite et facultative.';
COMMENT ON FUNCTION logistique.verifier_precision_unite() IS 'Référence catégorie34, précision0..3 ; refuse une réduction incompatible avec le stock ou son historique.';
COMMENT ON FUNCTION logistique.fn_verifier_quantite(integer,numeric) IS 'Valide quantité exacte bornée et précision explicitement autorisée par unité ; absence de politique conserve les quantités entières.';
COMMENT ON FUNCTION logistique.tr_quantite_unite() IS 'Défense SQL commune article, ligne, mouvement et ventilation ; aucun effet de stock supplémentaire.';
COMMENT ON FUNCTION logistique.verifier_inventaire() IS 'Propriétaire et auteur immuables, historique validé conservé, contrôle unité/article/entreprise et bon d’écart.';
COMMENT ON FUNCTION logistique.controler_inventaire_valide() IS 'Validation différée : un inventaire non vide doit relier chaque écart et seulement les écarts à un bon correcteur.';
COMMENT ON FUNCTION logistique.proteger_bon_inventaire() IS 'Préserve les bons compensateurs et leurs mouvements après validation du comptage ; une correction exige un nouveau document.';
COMMENT ON COLUMN logistique."T_Mouvement"."QteMvt" IS 'Quantité positive exacte à trois décimales au maximum ; sens porté par le type, précision autorisée par l’unité de stock.';
COMMENT ON COLUMN logistique."T_MouvementLot"."Quantite" IS 'Quantité positive exacte affectée au lot, même unité et précision que son mouvement, sans second effet sur le stock.';
COMMENT ON COLUMN logistique."T_CommandeDetail"."QteCmdDetail" IS 'Quantité strictement positive exacte, précision0..3 autorisée explicitement par unité de stock.';
COMMENT ON COLUMN logistique."T_Article"."QteMinArticle" IS 'Seuil minimum exact dans l’unité de stock ; précision identique au stock, NULL signifie absence de seuil.';
COMMENT ON COLUMN logistique."T_FactureLigne"."QteSortie" IS 'Quantité originale exacte de sortie dans l’unité figée sur la facture.';
COMMENT ON COLUMN logistique."T_FactureLigne"."QteRetourAvantFacture" IS 'Quantité exacte restituée avant émission de la facture.';
COMMENT ON COLUMN logistique."T_FactureLigne"."QteFacturee" IS 'Quantité nette exacte facturée après restitutions antérieures.';
COMMENT ON CONSTRAINT facture_ligne_montant_arrondi ON logistique."T_FactureLigne" IS 'Montant arrondi par ligne à deux décimales selon PostgreSQL numeric, avant sommation.';
COMMENT ON PROCEDURE logistique.ps_crud_commandedetail(integer,integer,numeric,numeric,integer,integer,numeric,numeric,character varying) IS 'Delta exact sous verrou et mouvement unique par ligne ; fractions selon politique explicite d’unité ; lots contrôlés séparément en fin de transaction.';
COMMENT ON PROCEDURE logistique.ps_update_totaux_commande(integer) IS 'Somme des montants quantité exacte fois prix, arrondis par ligne à deux décimales ; pas de taxe ni conversion implicite.';
-- Commentaires exhaustifs pour chaque colonne et trigger créé : noms métier conservés.
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name IN ('T_UniteStockPrecision','T_Inventaire','T_InventaireLigne','V_Inventaire','V_InventaireLigne','V_LotDisponibilite') LOOP
 EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',r.table_name,r.column_name,
 CASE r.column_name WHEN 'IdEntiteFk' THEN 'Entreprise propriétaire stable ; ne découle jamais du rattachement actuel de l’auteur.' WHEN 'Lots' THEN 'Ventilation JSON des seuls écarts : numéro, quantité exacte et péremption facultative ; aucun mouvement autonome.' WHEN 'QteTheorique' THEN 'Stock exact capturé lors de la préparation du comptage, contrôlé de nouveau sous verrou à la validation.' WHEN 'QteComptee' THEN 'Quantité physique saisie explicitement ; zéro est un comptage, absence est refusée.' WHEN 'ValidationRequest' THEN 'Identifiant de demande idempotente de validation ; un rejeu identique conserve les mêmes bons.' WHEN 'Version' THEN 'Version optimiste incrémentée à chaque modification, indépendante des variations de stock.' WHEN 'Decimales' THEN 'Nombre de décimales autorisées explicitement pour cette unité (0 à 3).' ELSE 'Donnée '||r.column_name||' de '||r.table_name||', consultée dans le périmètre entreprise autorisé.' END);
 END LOOP;
 FOR r IN SELECT t.tgname,c.relname FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid WHERE t.tgname IN ('precision_unite_integrite','quantite_unite_article','quantite_unite_ligne','quantite_unite_mouvement','quantite_unite_lot','inventaire_integrite','inventaire_ligne_integrite','inventaire_validation_complete','aa_inventaire_bon_protection','aa_inventaire_ligne_protection','aa_inventaire_mouvement_protection') LOOP
 EXECUTE format('COMMENT ON TRIGGER %I ON logistique.%I IS %L',r.tgname,r.relname,'Contrôle métier '||r.tgname||' : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.');END LOOP;
END $$;
COMMIT;
