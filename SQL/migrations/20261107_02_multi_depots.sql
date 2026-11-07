-- Multi-dépôts. À exécuter exclusivement par migrer_metier après sauvegarde vérifiée.
-- Le stock global existant reste la somme physique ; le transit n'est pas disponible.
SET LOCAL lock_timeout = '15s';
SET LOCAL statement_timeout = '180s';
DO $$ BEGIN
 IF EXISTS(SELECT FROM logistique."T_Article" a WHERE a."IdEntiteFk" IS NULL OR a."QteArticle" IS DISTINCT FROM
  (SELECT coalesce(sum(m."QteMvt"*logistique.fn_effet_type_bon(m."ID_TypeMvtFk")),0) FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=a."ID_Article"))
 OR EXISTS(SELECT FROM logistique."T_Commande" WHERE "IdEntiteFk" IS NULL)
 OR EXISTS(SELECT FROM logistique."T_Inventaire" WHERE "IdEntiteFk" IS NULL)
 OR EXISTS(SELECT FROM logistique."T_Mouvement" m JOIN logistique."T_Commande" c ON c."ID_Commande"=m."ID_cmdFk"
  JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE a."IdEntiteFk"<>c."IdEntiteFk")
 OR EXISTS(SELECT FROM logistique."V_LotArticleStock" WHERE "StockLot"<0)
 OR EXISTS(SELECT FROM logistique."T_Article" a WHERE a."QteArticle"<0 OR a."QteArticle"<
  (SELECT coalesce(sum(l."StockLot"),0) FROM logistique."V_LotArticleStock" l WHERE l."ID_ArticleFk"=a."ID_Article")) THEN
  RAISE EXCEPTION 'Migration dépôts refusée : propriétaire absent ou écart de stock historique. Exécutez le précontrôle et corrigez les cas vérifiés avant de reprendre.' USING ERRCODE='23514';END IF;
END $$;

CREATE TABLE logistique."T_Depot" (
 "ID_Depot" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "CodeDepot" text NOT NULL DEFAULT '', "NomDepot" text NOT NULL,
 "Principal" boolean NOT NULL DEFAULT false, "Actif" boolean NOT NULL DEFAULT true,
 "AdresseDepot" text, "Version" bigint NOT NULL DEFAULT 1 CHECK ("Version">0),
 "ID_UserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(), "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK (char_length(btrim("NomDepot")) BETWEEN 1 AND 120),
 CHECK (char_length("CodeDepot")<=60), CHECK (char_length("AdresseDepot")<=1000),
 CHECK (NOT "Principal" OR "Actif")
);
CREATE UNIQUE INDEX depot_code_unique ON logistique."T_Depot"("IdEntiteFk",lower(btrim("CodeDepot")));
CREATE UNIQUE INDEX depot_principal_unique ON logistique."T_Depot"("IdEntiteFk") WHERE "Principal";

CREATE FUNCTION logistique.fn_preparer_depot() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Désactivez le dépôt pour conserver son historique.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' THEN
  NEW."CodeDepot"=coalesce(nullif(btrim(NEW."CodeDepot"),''),'DEP-'||NEW."ID_Depot"::text);
 ELSE
  IF NEW."IdEntiteFk"<>OLD."IdEntiteFk" OR NEW."ID_Depot"<>OLD."ID_Depot" OR NEW."CreeLe"<>OLD."CreeLe" THEN
   RAISE EXCEPTION 'L’identité et l’entreprise du dépôt sont conservées.' USING ERRCODE='23514';END IF;
  NEW."Version"=OLD."Version"+1;NEW."ModifieLe"=clock_timestamp();
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER depot_preparer BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Depot" FOR EACH ROW EXECUTE FUNCTION logistique.fn_preparer_depot();
CREATE FUNCTION logistique.fn_depot_principal(p_entite integer) RETURNS bigint LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT "ID_Depot" FROM logistique."T_Depot" WHERE "IdEntiteFk"=p_entite AND "Principal" AND "Actif"
$$;
CREATE FUNCTION logistique.fn_creer_depot_principal() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 INSERT INTO logistique."T_Depot"("IdEntiteFk","NomDepot","Principal") VALUES(NEW."IdEntite",'Dépôt principal',true);
 RETURN NEW;
END $$;
CREATE TRIGGER entite_depot_principal AFTER INSERT ON systeme."T_Entite" FOR EACH ROW EXECUTE FUNCTION logistique.fn_creer_depot_principal();
INSERT INTO logistique."T_Depot"("IdEntiteFk","NomDepot","Principal")
 SELECT "IdEntite",'Dépôt principal',true FROM systeme."T_Entite" e
 WHERE NOT EXISTS(SELECT FROM logistique."T_Depot" d WHERE d."IdEntiteFk"=e."IdEntite" AND d."Principal");

ALTER TABLE logistique."T_Commande" ADD COLUMN "ID_DepotFk" bigint REFERENCES logistique."T_Depot"("ID_Depot") ON DELETE RESTRICT;
ALTER TABLE logistique."T_Mouvement" ADD COLUMN "ID_DepotFk" bigint REFERENCES logistique."T_Depot"("ID_Depot") ON DELETE RESTRICT;
ALTER TABLE logistique."T_Inventaire" ADD COLUMN "ID_DepotFk" bigint REFERENCES logistique."T_Depot"("ID_Depot") ON DELETE RESTRICT;
-- Les protections des documents émis sont temporairement suspendues uniquement
-- pour ce rattachement NULL -> principal, sous verrou exclusif dans la transaction.
-- Aucun prix, quantité, code, statut, auteur ni mouvement n'est réécrit.
LOCK TABLE logistique."T_Commande",logistique."T_Mouvement",logistique."T_Inventaire" IN ACCESS EXCLUSIVE MODE;
DO $$ DECLARE t record;disabled jsonb;BEGIN
 SELECT jsonb_agg(jsonb_build_object('relname',c.relname,'tgname',tg.tgname)) INTO disabled FROM pg_trigger tg JOIN pg_class c ON c.oid=tg.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='logistique'
   AND c.relname IN('T_Commande','T_Mouvement','T_Inventaire') AND NOT tg.tgisinternal AND (tg.tgtype & 2)=2 AND tg.tgenabled='O';
 FOR t IN SELECT * FROM jsonb_to_recordset(disabled) AS x(relname text,tgname text)
 LOOP EXECUTE format('ALTER TABLE logistique.%I DISABLE TRIGGER %I',t.relname,t.tgname);END LOOP;
 UPDATE logistique."T_Commande" SET "ID_DepotFk"=logistique.fn_depot_principal("IdEntiteFk") WHERE "ID_DepotFk" IS NULL;
 UPDATE logistique."T_Mouvement" m SET "ID_DepotFk"=coalesce((SELECT c."ID_DepotFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=m."ID_cmdFk"),logistique.fn_depot_principal(a."IdEntiteFk"))
  FROM logistique."T_Article" a WHERE a."ID_Article"=m."ID_ArticleFk" AND m."ID_DepotFk" IS NULL;
 UPDATE logistique."T_Inventaire" SET "ID_DepotFk"=logistique.fn_depot_principal("IdEntiteFk") WHERE "ID_DepotFk" IS NULL;
 SET CONSTRAINTS ALL IMMEDIATE;
 FOR t IN SELECT * FROM jsonb_to_recordset(disabled) AS x(relname text,tgname text)
 LOOP EXECUTE format('ALTER TABLE logistique.%I ENABLE TRIGGER %I',t.relname,t.tgname);END LOOP;
END $$;
SET CONSTRAINTS ALL DEFERRED;
ALTER TABLE logistique."T_Commande" ALTER COLUMN "ID_DepotFk" SET NOT NULL;
ALTER TABLE logistique."T_Mouvement" ALTER COLUMN "ID_DepotFk" SET NOT NULL;
ALTER TABLE logistique."T_Inventaire" ALTER COLUMN "ID_DepotFk" SET NOT NULL;
CREATE INDEX commande_depot_idx ON logistique."T_Commande"("ID_DepotFk");
CREATE INDEX mouvement_depot_article_idx ON logistique."T_Mouvement"("ID_DepotFk","ID_ArticleFk");
CREATE INDEX inventaire_depot_idx ON logistique."T_Inventaire"("ID_DepotFk");

-- Les états sont des valeurs centrales et leurs identifiants sont résolus au serveur.
DO $$ DECLARE cat integer;r record;BEGIN
 SELECT "ID_CategorieGenerique" INTO cat FROM referentiel."T_CategorieGenerique" WHERE "NomCategorieGenerique"='État de transfert interne' AND "IdEntiteFk" IS NULL;
 IF cat IS NULL THEN INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ModuleCategorieGenerique") VALUES('État de transfert interne','M_LOG') RETURNING "ID_CategorieGenerique" INTO cat;END IF;
 FOR r IN SELECT * FROM (VALUES ('TR_BROUILLON','Brouillon'),('TR_VALIDE','Validé'),('TR_TRANSIT','En transit'),('TR_PARTIEL','Partiellement reçu'),('TR_TERMINE','Terminé'),('TR_ANNULE','Annulé')) v(code,label)
 LOOP
  IF NOT EXISTS(SELECT FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=cat AND "AbrGenerique"=r.code) THEN
   INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique") VALUES(cat,r.label,r.code);END IF;
 END LOOP;
END $$;
CREATE FUNCTION logistique.fn_etat_transfert(p_code text) RETURNS integer LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT g."ID_Generique" FROM referentiel."T_Generique" g
 WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_TransfertDepot','ID_EtatFk',NULL))
 AND g."AbrGenerique"=p_code AND g."ValideGenerique"
$$;
CREATE TABLE logistique."T_TransfertDepot" (
 "ID_TransfertDepot" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "CodeTransfert" text GENERATED ALWAYS AS ('TRF-'||"ID_TransfertDepot"::text) STORED UNIQUE,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "ID_DepotSourceFk" bigint NOT NULL REFERENCES logistique."T_Depot"("ID_Depot") ON DELETE RESTRICT,
 "ID_DepotDestinationFk" bigint NOT NULL REFERENCES logistique."T_Depot"("ID_Depot") ON DELETE RESTRICT,
 "ID_DeviseFk" integer NOT NULL DEFAULT logistique.fn_devise_usd() REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_EtatFk" integer NOT NULL DEFAULT logistique.fn_etat_transfert('TR_BROUILLON') REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "DateTransfert" timestamptz NOT NULL DEFAULT clock_timestamp(), "Motif" text NOT NULL,
 "ReferenceTransfert" text, "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "Version" bigint NOT NULL DEFAULT 1 CHECK("Version">0),
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(), "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK("ID_DepotSourceFk"<>"ID_DepotDestinationFk"), CHECK(char_length(btrim("Motif")) BETWEEN 1 AND 1000),CHECK(char_length("ReferenceTransfert")<=255)
);
ALTER TABLE logistique."T_Commande" ADD COLUMN "ID_TransfertDepotFk" bigint REFERENCES logistique."T_TransfertDepot"("ID_TransfertDepot") ON DELETE RESTRICT,
 ADD COLUMN "OperationTransfert" text CHECK("OperationTransfert" IN('expedition','reception','retour')),
 ADD CONSTRAINT commande_transfert_exact CHECK (("ID_TransfertDepotFk" IS NULL)=("OperationTransfert" IS NULL));
CREATE TABLE logistique."T_TransfertDepotLigne" (
 "ID_TransfertDepotFk" bigint NOT NULL REFERENCES logistique."T_TransfertDepot"("ID_TransfertDepot") ON DELETE RESTRICT,
 "ID_ArticleFk" integer NOT NULL REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 "QteDemandee" numeric(14,3) NOT NULL CHECK("QteDemandee">0), "Lots" jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof("Lots")='array'),
 "ObsLigne" text CHECK(char_length("ObsLigne")<=2000), PRIMARY KEY("ID_TransfertDepotFk","ID_ArticleFk")
);
CREATE TABLE logistique."T_TransfertDepotAction" (
 "ID_Action" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_TransfertDepotFk" bigint NOT NULL REFERENCES logistique."T_TransfertDepot"("ID_TransfertDepot") ON DELETE RESTRICT,
 "Action" text NOT NULL CHECK("Action" IN('creer','modifier','valider','expedier','recevoir','retourner','annuler','clore_ecart')),
 "RequestId" uuid NOT NULL, "PayloadHash" varchar(64) NOT NULL CHECK("PayloadHash" ~ '^[0-9a-f]{64}$'),
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "Motif" text CHECK(char_length("Motif")<=2000), "DateAction" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "ID_CommandeFk" integer UNIQUE REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT,
 "Lignes" jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof("Lignes")='array'), UNIQUE("ID_UserFk","RequestId"),
 CHECK(("Action" IN('expedier','recevoir','retourner'))=("ID_CommandeFk" IS NOT NULL)),
 CHECK("Action" NOT IN('annuler','clore_ecart','retourner') OR nullif(btrim("Motif"),'') IS NOT NULL)
);
CREATE UNIQUE INDEX transfert_expedition_unique ON logistique."T_TransfertDepotAction"("ID_TransfertDepotFk") WHERE "Action"='expedier';
CREATE UNIQUE INDEX transfert_validation_unique ON logistique."T_TransfertDepotAction"("ID_TransfertDepotFk") WHERE "Action"='valider';
CREATE INDEX transfert_entreprise_etat_idx ON logistique."T_TransfertDepot"("IdEntiteFk","ID_EtatFk");
CREATE INDEX transfert_action_parent_idx ON logistique."T_TransfertDepotAction"("ID_TransfertDepotFk","ID_Action");
CREATE INDEX commande_transfert_idx ON logistique."T_Commande"("ID_TransfertDepotFk") WHERE "ID_TransfertDepotFk" IS NOT NULL;

INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName","ID_CategorieDefautFk","CanConfigure","SupportsEntityScope")
 SELECT 'logistique','T_TransfertDepot','ID_EtatFk','État du transfert','logistique',"ID_CategorieGenerique",false,false FROM referentiel."T_CategorieGenerique" WHERE "NomCategorieGenerique"='État de transfert interne' AND "IdEntiteFk" IS NULL;
INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName","ID_CategorieDefautFk","CanConfigure","SupportsEntityScope")
 SELECT 'logistique','T_TransfertDepot','ID_DeviseFk','Devise du transfert','logistique',"ID_CategorieDefautFk",true,true FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='logistique' AND "TableName"='T_Commande' AND "ColumnName"='ID_DeviseFk';

CREATE VIEW logistique."V_TransfertDepotLigne" AS
 WITH quantities AS (
 SELECT c."ID_TransfertDepotFk" AS id,d."ID_ArticleFk" AS article,
 coalesce(sum(d."QteCmdDetail") FILTER(WHERE c."OperationTransfert"='expedition'),0) AS expedie,
 coalesce(sum(d."QteCmdDetail") FILTER(WHERE c."OperationTransfert"='reception'),0) AS recu,
 coalesce(sum(d."QteCmdDetail") FILTER(WHERE c."OperationTransfert"='retour'),0) AS retourne
 FROM logistique."T_Commande" c JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=c."ID_Commande"
 WHERE c."ID_TransfertDepotFk" IS NOT NULL GROUP BY 1,2),
 gaps AS (SELECT a."ID_TransfertDepotFk" AS id,(j->>'ID_ArticleFk')::integer AS article,sum((j->>'Quantite')::numeric) AS ecart
 FROM logistique."T_TransfertDepotAction" a CROSS JOIN LATERAL jsonb_array_elements(a."Lignes") j WHERE a."Action"='clore_ecart' GROUP BY 1,2)
 SELECT l.*,coalesce(q.expedie,0) AS "QteExpediee",coalesce(q.recu,0) AS "QteRecue",coalesce(q.retourne,0) AS "QteRetournee",coalesce(g.ecart,0) AS "QteEcart",
 coalesce(q.expedie,0)-coalesce(q.recu,0)-coalesce(q.retourne,0)-coalesce(g.ecart,0) AS "QteTransit",
 CASE WHEN t."ID_EtatFk"=logistique.fn_etat_transfert('TR_VALIDE') AND coalesce(q.expedie,0)=0 THEN l."QteDemandee" ELSE 0 END AS "QteReservee"
 FROM logistique."T_TransfertDepotLigne" l JOIN logistique."T_TransfertDepot" t ON t."ID_TransfertDepot"=l."ID_TransfertDepotFk"
 LEFT JOIN quantities q ON q.id=l."ID_TransfertDepotFk" AND q.article=l."ID_ArticleFk" LEFT JOIN gaps g ON g.id=l."ID_TransfertDepotFk" AND g.article=l."ID_ArticleFk";

CREATE VIEW logistique."V_StockLotDepot" AS
 SELECT m."ID_DepotFk",ml."ID_LotArticleFk",m."ID_ArticleFk",sum(ml."Quantite"*logistique.fn_effet_type_bon(m."ID_TypeMvtFk")) AS "StockLot"
 FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk" GROUP BY 1,2,3;
CREATE VIEW logistique."V_ReservationLotDepot" AS
 SELECT t."ID_DepotSourceFk" AS "ID_DepotFk",l."ID_ArticleFk",a."ID_LotArticle" AS "ID_LotArticleFk",sum((j->>'Quantite')::numeric) AS "StockReserve"
 FROM logistique."V_TransfertDepotLigne" l JOIN logistique."T_TransfertDepot" t ON t."ID_TransfertDepot"=l."ID_TransfertDepotFk"
 CROSS JOIN LATERAL jsonb_array_elements(l."Lots") j LEFT JOIN logistique."T_LotArticle" a ON a."ID_ArticleFk"=l."ID_ArticleFk" AND lower(btrim(a."NumeroLot"))=lower(btrim(j->>'NumeroLot'))
 WHERE l."QteReservee">0 GROUP BY 1,2,3;
CREATE VIEW logistique."V_StockDepot" AS
 WITH stocks AS (SELECT "ID_DepotFk","ID_ArticleFk",sum("QteMvt"*logistique.fn_effet_type_bon("ID_TypeMvtFk")) AS physique FROM logistique."T_Mouvement" GROUP BY 1,2),
 reserves AS (SELECT t."ID_DepotSourceFk" AS depot,l."ID_ArticleFk" AS article,sum(l."QteReservee") AS qte FROM logistique."V_TransfertDepotLigne" l JOIN logistique."T_TransfertDepot" t ON t."ID_TransfertDepot"=l."ID_TransfertDepotFk" GROUP BY 1,2),
 lots AS (SELECT l."ID_DepotFk",l."ID_ArticleFk",sum(l."StockLot") AS qte,
 sum(CASE WHEN NOT a."Actif" OR (e."BloquerLotsPerimes" AND a."DatePeremptionLot"<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date) THEN greatest(l."StockLot",0) ELSE 0 END) AS indisponible
 FROM logistique."V_StockLotDepot" l JOIN logistique."T_LotArticle" a ON a."ID_LotArticle"=l."ID_LotArticleFk"
 JOIN logistique."T_Depot" d ON d."ID_Depot"=l."ID_DepotFk" JOIN systeme."T_Entite" e ON e."IdEntite"=d."IdEntiteFk" GROUP BY 1,2)
 SELECT d."ID_Depot" AS "ID_DepotFk",a."ID_Article" AS "ID_ArticleFk",d."IdEntiteFk",
 coalesce(s.physique,0) AS "StockPhysique",coalesce(r.qte,0) AS "StockReserve",greatest(coalesce(s.physique,0)-coalesce(r.qte,0)-coalesce(l.indisponible,0),0) AS "StockDisponible",
 coalesce(s.physique,0)-coalesce(l.qte,0) AS "StockSansLot",coalesce(l.indisponible,0) AS "StockIndisponible"
 FROM logistique."T_Depot" d JOIN logistique."T_Article" a ON a."IdEntiteFk"=d."IdEntiteFk"
 LEFT JOIN stocks s ON s."ID_DepotFk"=d."ID_Depot" AND s."ID_ArticleFk"=a."ID_Article"
 LEFT JOIN reserves r ON r.depot=d."ID_Depot" AND r.article=a."ID_Article" LEFT JOIN lots l ON l."ID_DepotFk"=d."ID_Depot" AND l."ID_ArticleFk"=a."ID_Article";
CREATE VIEW logistique."V_Depot" AS SELECT d.*,e."NomEntite",coalesce(s.articles,0) AS "NbArticles",coalesce(s.qte,0) AS "StockPhysique",coalesce(s.reserve,0) AS "StockReserve"
 FROM logistique."T_Depot" d JOIN systeme."T_Entite" e ON e."IdEntite"=d."IdEntiteFk"
 LEFT JOIN LATERAL(SELECT count(*) FILTER(WHERE "StockPhysique"<>0) AS articles,sum("StockPhysique") AS qte,sum("StockReserve") AS reserve FROM logistique."V_StockDepot" WHERE "ID_DepotFk"=d."ID_Depot") s ON true;
CREATE VIEW logistique."V_TransfertDepot" AS SELECT t.*,g."AbrGenerique" AS "EtatCode",g."NomGenerique" AS "EtatLibelle",s."NomDepot" AS "DepotSource",d."NomDepot" AS "DepotDestination",
 coalesce(l.n,0) AS "NbLignes",coalesce(l.transit,0) AS "QteTransit",coalesce(l.expedie,0) AS "QteExpediee",coalesce(l.recu,0) AS "QteRecue",coalesce(l.retourne,0) AS "QteRetournee",coalesce(l.ecart,0) AS "QteEcart"
 FROM logistique."T_TransfertDepot" t JOIN referentiel."T_Generique" g ON g."ID_Generique"=t."ID_EtatFk"
 JOIN logistique."T_Depot" s ON s."ID_Depot"=t."ID_DepotSourceFk" JOIN logistique."T_Depot" d ON d."ID_Depot"=t."ID_DepotDestinationFk"
 LEFT JOIN LATERAL(SELECT count(*) AS n,sum("QteTransit") AS transit,sum("QteExpediee") AS expedie,sum("QteRecue") AS recu,sum("QteRetournee") AS retourne,sum("QteEcart") AS ecart FROM logistique."V_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=t."ID_TransfertDepot") l ON true;

CREATE FUNCTION logistique.fn_bon_transfert(p_commande integer) RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT FROM logistique."T_Commande" WHERE "ID_Commande"=p_commande AND "ID_TransfertDepotFk" IS NOT NULL)
$$;

CREATE FUNCTION logistique.fn_verifier_depot_document() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE dep logistique."T_Depot";t logistique."T_TransfertDepot";id_entity integer;bon integer;
BEGIN
 IF TG_TABLE_NAME='T_Mouvement' THEN
  SELECT c."ID_DepotFk",c."IdEntiteFk" INTO NEW."ID_DepotFk",id_entity FROM logistique."T_Commande" c WHERE c."ID_Commande"=NEW."ID_cmdFk";
  IF NOT FOUND THEN RAISE EXCEPTION 'Un nouveau mouvement doit provenir d’un bon identifié.' USING ERRCODE='23514';END IF;
  IF TG_OP='UPDATE' AND (NEW."ID_DepotFk"<>OLD."ID_DepotFk" OR NEW."ID_cmdFk"<>OLD."ID_cmdFk") THEN
   RAISE EXCEPTION 'Le dépôt et le bon du mouvement sont conservés.' USING ERRCODE='23514';END IF;
 ELSE
  id_entity=NEW."IdEntiteFk";
  NEW."ID_DepotFk"=coalesce(NEW."ID_DepotFk",logistique.fn_depot_principal(id_entity));
  IF TG_OP='UPDATE' AND NEW."ID_DepotFk"<>OLD."ID_DepotFk" THEN
   IF TG_TABLE_NAME='T_Inventaire' OR EXISTS(SELECT FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=NEW."ID_Commande") THEN
    RAISE EXCEPTION 'Le dépôt d’un document contenant des lignes est conservé ; créez un nouveau document.' USING ERRCODE='23514';END IF;
  END IF;
 END IF;
 SELECT * INTO dep FROM logistique."T_Depot" WHERE "ID_Depot"=NEW."ID_DepotFk" FOR SHARE;
 IF dep."ID_Depot" IS NULL OR dep."IdEntiteFk"<>id_entity OR (NOT dep."Actif" AND (TG_OP='INSERT' OR TG_TABLE_NAME='T_Mouvement' OR NEW."ID_DepotFk" IS DISTINCT FROM OLD."ID_DepotFk")) THEN
  RAISE EXCEPTION 'Choisissez un dépôt actif de l’entreprise du document.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_Commande' THEN
 IF NEW."ID_TransfertDepotFk" IS NOT NULL THEN
  SELECT * INTO t FROM logistique."T_TransfertDepot" WHERE "ID_TransfertDepot"=NEW."ID_TransfertDepotFk" FOR NO KEY UPDATE;
  IF t."IdEntiteFk"<>id_entity OR t."ID_DeviseFk"<>NEW."ID_DeviseFk" OR NEW."ID_DepotFk"<>(CASE WHEN NEW."OperationTransfert"='reception' THEN t."ID_DepotDestinationFk" ELSE t."ID_DepotSourceFk" END)
   OR logistique.fn_nature_bon(NEW."ID_TypeCmdFk")<>(CASE WHEN NEW."OperationTransfert"='expedition' THEN 'sortie' ELSE 'entree' END)
   OR NEW."CodeFacture" IS NOT NULL OR NEW."DateFacture" IS NOT NULL THEN
   RAISE EXCEPTION 'Bon interne incompatible avec le transfert, son sens, son dépôt ou sa devise.' USING ERRCODE='23514';END IF;
 END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER a00_depot_document BEFORE INSERT OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.fn_verifier_depot_document();
CREATE TRIGGER a00_depot_mouvement BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.fn_verifier_depot_document();
CREATE TRIGGER a00_depot_inventaire BEFORE INSERT OR UPDATE ON logistique."T_Inventaire" FOR EACH ROW EXECUTE FUNCTION logistique.fn_verifier_depot_document();

CREATE FUNCTION logistique.fn_proteger_transfert() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE t logistique."T_TransfertDepot";a logistique."T_Article";code text;oldcode text;
BEGIN
 IF TG_OP='DELETE' AND TG_TABLE_NAME<>'T_TransfertDepotLigne' THEN RAISE EXCEPTION 'Le transfert et ses preuves restent dans l’historique.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_TransfertDepot' THEN
  PERFORM 1 FROM logistique."T_Depot" WHERE "ID_Depot" IN(NEW."ID_DepotSourceFk",NEW."ID_DepotDestinationFk") ORDER BY "ID_Depot" FOR SHARE;
  IF (SELECT count(*) FROM logistique."T_Depot" WHERE "ID_Depot" IN(NEW."ID_DepotSourceFk",NEW."ID_DepotDestinationFk") AND "IdEntiteFk"=NEW."IdEntiteFk" AND "Actif")<>2 THEN
   RAISE EXCEPTION 'Les deux dépôts doivent être distincts, actifs et appartenir à la même entreprise.' USING ERRCODE='23514';END IF;
  SELECT "AbrGenerique" INTO code FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."ID_EtatFk";
  IF NEW."ID_EtatFk" IS DISTINCT FROM logistique.fn_etat_transfert(code) THEN RAISE EXCEPTION 'État de transfert inconnu.' USING ERRCODE='23514';END IF;
  IF TG_OP='INSERT' AND code<>'TR_BROUILLON' THEN RAISE EXCEPTION 'Créez d’abord le brouillon du transfert.' USING ERRCODE='23514';END IF;
  IF TG_OP='UPDATE' THEN
   SELECT "AbrGenerique" INTO oldcode FROM referentiel."T_Generique" WHERE "ID_Generique"=OLD."ID_EtatFk";
   IF NEW."IdEntiteFk"<>OLD."IdEntiteFk" OR NEW."ID_UserFk"<>OLD."ID_UserFk" OR NEW."CreeLe"<>OLD."CreeLe" OR oldcode IN('TR_ANNULE','TR_TERMINE') THEN
    RAISE EXCEPTION 'Le transfert terminé et son identité sont conservés.' USING ERRCODE='23514';END IF;
   IF oldcode<>'TR_BROUILLON' AND (to_jsonb(NEW)-ARRAY['ID_EtatFk','Version','ModifieLe','CodeTransfert']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['ID_EtatFk','Version','ModifieLe','CodeTransfert']) THEN
    RAISE EXCEPTION 'Les données du transfert validé sont conservées.' USING ERRCODE='23514';END IF;
   IF oldcode<>code AND NOT (oldcode='TR_BROUILLON' AND code IN('TR_VALIDE','TR_ANNULE') OR oldcode='TR_VALIDE' AND code IN('TR_TRANSIT','TR_ANNULE') OR oldcode IN('TR_TRANSIT','TR_PARTIEL') AND code IN('TR_TRANSIT','TR_PARTIEL','TR_TERMINE','TR_ANNULE')) THEN
    RAISE EXCEPTION 'Transition de transfert impossible.' USING ERRCODE='23514';END IF;
   NEW."Version"=OLD."Version"+1;NEW."ModifieLe"=clock_timestamp();
  END IF;
  RETURN NEW;
 END IF;
 IF TG_TABLE_NAME='T_TransfertDepotAction' AND TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Les preuves de transfert sont immuables.' USING ERRCODE='23514';END IF;
 SELECT * INTO t FROM logistique."T_TransfertDepot" WHERE "ID_TransfertDepot"=coalesce(NEW."ID_TransfertDepotFk",OLD."ID_TransfertDepotFk") FOR NO KEY UPDATE;
 IF TG_TABLE_NAME='T_TransfertDepotLigne' THEN
  IF t."ID_EtatFk"<>logistique.fn_etat_transfert('TR_BROUILLON') THEN RAISE EXCEPTION 'Les lignes validées sont conservées.' USING ERRCODE='23514';END IF;
  IF TG_OP='DELETE' THEN RETURN OLD;END IF;
  IF TG_OP='UPDATE' AND (NEW."ID_TransfertDepotFk"<>OLD."ID_TransfertDepotFk" OR NEW."ID_ArticleFk"<>OLD."ID_ArticleFk") THEN RAISE EXCEPTION 'Identité de ligne conservée.' USING ERRCODE='23514';END IF;
  SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk" FOR NO KEY UPDATE;
  IF a."IdEntiteFk"<>t."IdEntiteFk" OR a."ID_DeviseFk"<>t."ID_DeviseFk" THEN RAISE EXCEPTION 'Article hors entreprise ou devise du transfert.' USING ERRCODE='23514';END IF;
  PERFORM logistique.fn_verifier_quantite(a."ID_UniteFk",NEW."QteDemandee");
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER transfert_integrite BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_TransfertDepot" FOR EACH ROW EXECUTE FUNCTION logistique.fn_proteger_transfert();
CREATE TRIGGER transfert_ligne_integrite BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_TransfertDepotLigne" FOR EACH ROW EXECUTE FUNCTION logistique.fn_proteger_transfert();
CREATE TRIGGER transfert_action_integrite BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_TransfertDepotAction" FOR EACH ROW EXECUTE FUNCTION logistique.fn_proteger_transfert();

CREATE FUNCTION logistique.fn_controler_stock_depots() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE ids integer[];article integer;d bigint;
BEGIN
 IF TG_TABLE_NAME='T_Mouvement' THEN ids=ARRAY[CASE WHEN TG_OP<>'INSERT' THEN OLD."ID_ArticleFk" END,CASE WHEN TG_OP<>'DELETE' THEN NEW."ID_ArticleFk" END];
 ELSIF TG_TABLE_NAME='T_MouvementLot' THEN SELECT array_agg(DISTINCT "ID_ArticleFk") INTO ids FROM logistique."T_Mouvement" WHERE "ID_Mvt"=ANY(ARRAY[CASE WHEN TG_OP<>'INSERT' THEN OLD."ID_MvtFk" END,CASE WHEN TG_OP<>'DELETE' THEN NEW."ID_MvtFk" END]);
 ELSIF TG_TABLE_NAME='T_TransfertDepotLigne' THEN ids=ARRAY[CASE WHEN TG_OP<>'INSERT' THEN OLD."ID_ArticleFk" END,CASE WHEN TG_OP<>'DELETE' THEN NEW."ID_ArticleFk" END];
 ELSE SELECT array_agg("ID_ArticleFk") INTO ids FROM logistique."T_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=coalesce(NEW."ID_TransfertDepot",OLD."ID_TransfertDepot");END IF;
 FOR article IN SELECT DISTINCT i FROM unnest(ids) i WHERE i IS NOT NULL ORDER BY i LOOP
  PERFORM 1 FROM logistique."T_Article" WHERE "ID_Article"=article FOR NO KEY UPDATE;
  IF EXISTS(SELECT FROM logistique."V_StockDepot" WHERE "ID_ArticleFk"=article AND ("StockPhysique"<0 OR "StockPhysique"-"StockIndisponible"<"StockReserve" OR "StockSansLot"<0)) THEN
   RAISE EXCEPTION 'Stock insuffisant dans ce dépôt, déjà réservé ou ventilation par lot incohérente.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT s."ID_DepotFk" FROM logistique."V_StockDepot" s JOIN logistique."T_TransfertDepot" t ON t."ID_DepotSourceFk"=s."ID_DepotFk"
   JOIN logistique."V_TransfertDepotLigne" l ON l."ID_TransfertDepotFk"=t."ID_TransfertDepot" AND l."ID_ArticleFk"=s."ID_ArticleFk"
   WHERE s."ID_ArticleFk"=article AND l."QteReservee">0 GROUP BY s."ID_DepotFk",s."StockSansLot"
   HAVING sum(l."QteReservee"-(SELECT coalesce(sum((j->>'Quantite')::numeric),0) FROM jsonb_array_elements(l."Lots") j))>s."StockSansLot") THEN
   RAISE EXCEPTION 'Le stock sans lot est déjà réservé ; sélectionnez les lots réellement disponibles dans le dépôt.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."V_StockLotDepot" WHERE "ID_ArticleFk"=article AND "StockLot"<0) THEN
   RAISE EXCEPTION 'Le lot ne possède pas la quantité disponible dans ce dépôt.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."V_ReservationLotDepot" r
   LEFT JOIN logistique."V_StockLotDepot" l ON l."ID_DepotFk"=r."ID_DepotFk" AND l."ID_ArticleFk"=r."ID_ArticleFk" AND l."ID_LotArticleFk"=r."ID_LotArticleFk"
   LEFT JOIN logistique."T_LotArticle" a ON a."ID_LotArticle"=r."ID_LotArticleFk"
   JOIN logistique."T_Depot" d ON d."ID_Depot"=r."ID_DepotFk" JOIN systeme."T_Entite" e ON e."IdEntite"=d."IdEntiteFk"
   WHERE r."ID_ArticleFk"=article AND (a."ID_LotArticle" IS NULL OR r."StockReserve"<=0 OR r."StockReserve">coalesce(l."StockLot",0) OR NOT a."Actif" OR (e."BloquerLotsPerimes" AND a."DatePeremptionLot"<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date))) THEN
   RAISE EXCEPTION 'Le lot réservé est inconnu, inactif, périmé bloqué ou déjà réservé dans ce dépôt.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."V_TransfertDepotLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
   WHERE l."ID_ArticleFk"=article AND l."QteReservee">0 AND ((SELECT coalesce(sum((j->>'Quantite')::numeric),0) FROM jsonb_array_elements(l."Lots") j)>l."QteDemandee"
    OR EXISTS(SELECT FROM jsonb_array_elements(l."Lots") j WHERE nullif(btrim(j->>'NumeroLot'),'') IS NULL OR (j->>'Quantite') IS NULL OR (j->>'Quantite')::numeric<=0))) THEN
   RAISE EXCEPTION 'La ventilation des lots réservés est invalide ou dépasse la quantité demandée.' USING ERRCODE='23514';END IF;
  IF (SELECT coalesce(sum("StockPhysique"),0) FROM logistique."V_StockDepot" WHERE "ID_ArticleFk"=article) IS DISTINCT FROM (SELECT "QteArticle" FROM logistique."T_Article" WHERE "ID_Article"=article) THEN
   RAISE EXCEPTION 'Le stock des dépôts ne correspond pas au stock physique de l’article.' USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER depot_stock_mouvement AFTER INSERT OR UPDATE OR DELETE ON logistique."T_Mouvement" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.fn_controler_stock_depots();
CREATE CONSTRAINT TRIGGER depot_stock_lot AFTER INSERT OR UPDATE OR DELETE ON logistique."T_MouvementLot" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.fn_controler_stock_depots();
CREATE CONSTRAINT TRIGGER depot_stock_reservation AFTER INSERT OR UPDATE OR DELETE ON logistique."T_TransfertDepotLigne" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.fn_controler_stock_depots();
CREATE CONSTRAINT TRIGGER depot_stock_transfert AFTER INSERT OR UPDATE ON logistique."T_TransfertDepot" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.fn_controler_stock_depots();

CREATE FUNCTION logistique.fn_controler_transfert_complet() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE id bigint;t logistique."T_TransfertDepot";code text;
BEGIN
 IF TG_TABLE_NAME='T_TransfertDepot' THEN id=coalesce(NEW."ID_TransfertDepot",OLD."ID_TransfertDepot");
 ELSIF TG_TABLE_NAME='T_Commande' THEN id=coalesce(NEW."ID_TransfertDepotFk",OLD."ID_TransfertDepotFk");
 ELSE id=coalesce(NEW."ID_TransfertDepotFk",OLD."ID_TransfertDepotFk");END IF;
 IF id IS NULL THEN RETURN NULL;END IF;
 SELECT * INTO t FROM logistique."T_TransfertDepot" WHERE "ID_TransfertDepot"=id FOR NO KEY UPDATE;
 SELECT "AbrGenerique" INTO code FROM referentiel."T_Generique" WHERE "ID_Generique"=t."ID_EtatFk";
 IF code NOT IN('TR_BROUILLON','TR_ANNULE') AND NOT EXISTS(SELECT FROM logistique."T_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=id) THEN
  RAISE EXCEPTION 'Ajoutez au moins un article au transfert.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT FROM logistique."V_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=id AND ("QteExpediee">"QteDemandee" OR "QteTransit"<0 OR "QteEcart"<0 OR "QteRecue"<0 OR "QteRetournee"<0 OR ("QteEcart">0 AND "QteTransit"<>0))) THEN
  RAISE EXCEPTION 'Les quantités reçues, retournées et écartées dépassent la quantité expédiée.' USING ERRCODE='23514';END IF;
 IF code NOT IN('TR_BROUILLON','TR_ANNULE') AND NOT EXISTS(SELECT FROM logistique."T_TransfertDepotAction" WHERE "ID_TransfertDepotFk"=id AND "Action"='valider') THEN
  RAISE EXCEPTION 'La validation du transfert exige une preuve de demande unique.' USING ERRCODE='23514';END IF;
 IF code IN('TR_BROUILLON','TR_VALIDE') AND EXISTS(SELECT FROM logistique."T_Commande" WHERE "ID_TransfertDepotFk"=id) THEN
  RAISE EXCEPTION 'Un bon exécuté exige le suivi en transit ou son solde ; le transfert ne peut rester en préparation.' USING ERRCODE='23514';END IF;
 IF code IN('TR_TRANSIT','TR_PARTIEL','TR_TERMINE') AND NOT EXISTS(SELECT FROM logistique."T_TransfertDepotAction" WHERE "ID_TransfertDepotFk"=id AND "Action"='expedier') THEN
  RAISE EXCEPTION 'Le suivi du transit exige un bon d’expédition unique.' USING ERRCODE='23514';END IF;
 IF code IN('TR_TRANSIT','TR_PARTIEL') AND NOT EXISTS(SELECT FROM logistique."V_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=id AND "QteTransit">0) THEN
  RAISE EXCEPTION 'Le transfert sans transit restant doit être terminé.' USING ERRCODE='23514';END IF;
 IF code='TR_ANNULE' AND EXISTS(SELECT FROM logistique."V_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=id AND "QteRecue">0) THEN
  RAISE EXCEPTION 'Les quantités déjà reçues sont conservées ; créez un transfert inverse.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT FROM logistique."T_TransfertDepotAction" a CROSS JOIN LATERAL jsonb_array_elements(a."Lignes") j
  WHERE a."ID_TransfertDepotFk"=id AND (a."Action"<>'clore_ecart' OR (j->>'Quantite')::numeric<=0 OR
   NOT EXISTS(SELECT FROM logistique."T_TransfertDepotLigne" l WHERE l."ID_TransfertDepotFk"=id AND l."ID_ArticleFk"=(j->>'ID_ArticleFk')::integer))) THEN
  RAISE EXCEPTION 'Le constat d’écart contient une quantité ou un article incompatible.' USING ERRCODE='23514';END IF;
 IF code IN('TR_TERMINE','TR_ANNULE') AND EXISTS(SELECT FROM logistique."V_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=id AND "QteTransit"<>0) THEN
  RAISE EXCEPTION 'Soldez le transit avant de terminer ou annuler le transfert.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT FROM logistique."T_Commande" c LEFT JOIN logistique."T_TransfertDepotAction" a ON a."ID_CommandeFk"=c."ID_Commande"
  WHERE c."ID_TransfertDepotFk"=id AND (a."ID_Action" IS NULL OR a."ID_TransfertDepotFk"<>id OR
   a."Action"<>CASE c."OperationTransfert" WHEN 'expedition' THEN 'expedier' WHEN 'reception' THEN 'recevoir' ELSE 'retourner' END)) THEN
  RAISE EXCEPTION 'Chaque bon interne doit posséder sa preuve de transfert unique.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT FROM logistique."T_TransfertDepotAction" a JOIN logistique."T_Commande" c ON c."ID_Commande"=a."ID_CommandeFk"
  WHERE a."ID_TransfertDepotFk"=id AND (c."ID_TransfertDepotFk" IS DISTINCT FROM id OR
   a."Action" IS DISTINCT FROM CASE c."OperationTransfert" WHEN 'expedition' THEN 'expedier' WHEN 'reception' THEN 'recevoir' WHEN 'retour' THEN 'retourner' END OR
   NOT EXISTS(SELECT FROM logistique."T_CommandeDetail" d WHERE d."ID_CmdFk"=c."ID_Commande"))) THEN
  RAISE EXCEPTION 'La preuve d’exécution doit désigner un bon non vide du même transfert et du même sens.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT FROM logistique."T_Commande" c JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=c."ID_Commande"
  WHERE c."ID_TransfertDepotFk"=id AND NOT EXISTS(SELECT FROM logistique."T_TransfertDepotLigne" l WHERE l."ID_TransfertDepotFk"=id AND l."ID_ArticleFk"=d."ID_ArticleFk")) THEN
  RAISE EXCEPTION 'Le bon interne contient un article étranger au transfert.' USING ERRCODE='23514';END IF;
 -- Les mêmes lots réellement expédiés doivent être reçus/retournés, jamais remplacés.
 IF EXISTS(SELECT ml."ID_LotArticleFk" FROM logistique."T_Commande" c JOIN logistique."T_Mouvement" m ON m."ID_cmdFk"=c."ID_Commande" JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
  WHERE c."ID_TransfertDepotFk"=id GROUP BY ml."ID_LotArticleFk"
  HAVING sum(CASE WHEN c."OperationTransfert"='expedition' THEN ml."Quantite" ELSE -ml."Quantite" END)<0) THEN
  RAISE EXCEPTION 'Un lot reçu ou retourné dépasse sa quantité expédiée.' USING ERRCODE='23514';END IF;
 RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER transfert_complet AFTER INSERT OR UPDATE ON logistique."T_TransfertDepot" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.fn_controler_transfert_complet();
CREATE CONSTRAINT TRIGGER transfert_action_complete AFTER INSERT ON logistique."T_TransfertDepotAction" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.fn_controler_transfert_complet();
CREATE CONSTRAINT TRIGGER transfert_bon_complet AFTER INSERT OR UPDATE ON logistique."T_Commande" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.fn_controler_transfert_complet();

CREATE FUNCTION logistique.fn_bloquer_document_transfert() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE bon integer;parent_id bigint;
BEGIN
 IF TG_TABLE_NAME='T_Commande' THEN
  IF OLD."ID_TransfertDepotFk" IS NULL THEN
   IF TG_OP='UPDATE' AND NEW."ID_TransfertDepotFk" IS NOT NULL THEN RAISE EXCEPTION 'Un bon ordinaire ne peut devenir un transfert.' USING ERRCODE='23514';END IF;
   RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
  END IF;
  bon=OLD."ID_Commande";
 ELSIF TG_TABLE_NAME='T_CommandeDetail' THEN bon=coalesce(NEW."ID_CmdFk",OLD."ID_CmdFk");
 ELSIF TG_TABLE_NAME='T_Mouvement' THEN bon=coalesce(NEW."ID_cmdFk",OLD."ID_cmdFk");
 ELSE SELECT "ID_cmdFk" INTO bon FROM logistique."T_Mouvement" WHERE "ID_Mvt"=coalesce(NEW."ID_MvtFk",OLD."ID_MvtFk");END IF;
 IF logistique.fn_bon_transfert(bon) AND EXISTS(SELECT FROM logistique."T_TransfertDepotAction" WHERE "ID_CommandeFk"=bon) THEN
  RAISE EXCEPTION 'Les mouvements et bons de transfert émis sont conservés ; utilisez une réception ou un retour.' USING ERRCODE='23514';END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER aa_transfert_bon_immutable BEFORE UPDATE OR DELETE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.fn_bloquer_document_transfert();
CREATE TRIGGER aa_transfert_ligne_immutable BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.fn_bloquer_document_transfert();
CREATE TRIGGER aa_transfert_mouvement_immutable BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.fn_bloquer_document_transfert();
CREATE TRIGGER aa_transfert_lot_immutable BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.fn_bloquer_document_transfert();

CREATE FUNCTION logistique.fn_transfert_non_commercial() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE doc integer;
BEGIN
 IF TG_TABLE_NAME='T_Facture' THEN doc=NEW."ID_CommandeFk";
 ELSIF TG_TABLE_NAME='T_RetourBon' THEN
  IF logistique.fn_bon_transfert(NEW."ID_CommandeOrigineFk") OR logistique.fn_bon_transfert(NEW."ID_CommandeRetourFk") THEN RAISE EXCEPTION 'Un transfert interne ne constitue pas une restitution commerciale.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 ELSE
  IF logistique.fn_bon_transfert(NEW."ID_CommandeCorrectionFk") OR logistique.fn_bon_transfert(NEW."ID_CommandeAnnulationFk") THEN RAISE EXCEPTION 'Un transfert interne ne constitue pas une correction d’inventaire.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 END IF;
 IF logistique.fn_bon_transfert(doc) THEN RAISE EXCEPTION 'Un transfert interne n’est pas facturable et ne produit aucun règlement ou encaissement.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER a00_facture_sans_transfert BEFORE INSERT OR UPDATE ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.fn_transfert_non_commercial();
CREATE TRIGGER a00_retour_sans_transfert BEFORE INSERT OR UPDATE ON logistique."T_RetourBon" FOR EACH ROW EXECUTE FUNCTION logistique.fn_transfert_non_commercial();
CREATE TRIGGER a00_inventaire_sans_transfert BEFORE INSERT OR UPDATE ON logistique."T_InventaireLigne" FOR EACH ROW EXECUTE FUNCTION logistique.fn_transfert_non_commercial();

CREATE FUNCTION logistique.fn_controler_depot_actif() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF OLD."Actif" AND NOT NEW."Actif" AND (
  EXISTS(SELECT FROM logistique."V_StockDepot" WHERE "ID_DepotFk"=NEW."ID_Depot" AND ("StockPhysique"<>0 OR "StockReserve"<>0)) OR
  EXISTS(SELECT FROM logistique."V_TransfertDepot" WHERE NEW."ID_Depot" IN("ID_DepotSourceFk","ID_DepotDestinationFk") AND "EtatCode" NOT IN('TR_TERMINE','TR_ANNULE')) OR
  EXISTS(SELECT FROM logistique."T_Inventaire" WHERE "ID_DepotFk"=NEW."ID_Depot" AND "Etat"='brouillon') OR
  EXISTS(SELECT FROM logistique."T_Commande" c LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_StatutCmdFk"
   WHERE c."ID_DepotFk"=NEW."ID_Depot" AND logistique.fn_nature_bon(c."ID_TypeCmdFk")='commande'
    AND coalesce(g."AbrGenerique",'') !~* '^(term|annul|clos)')) THEN
  RAISE EXCEPTION 'Ce dépôt possède du stock, une réservation ou une opération en cours.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER depot_desactivation BEFORE UPDATE ON logistique."T_Depot" FOR EACH ROW EXECUTE FUNCTION logistique.fn_controler_depot_actif();

-- La réception interne reprend le coût exact de la sortie source, pas le prix catalogue.
CREATE OR REPLACE FUNCTION logistique.fn_cout_mouvements(p_article integer, p_devise integer) RETURNS TABLE("ID_Mvt" integer, "ID_ArticleFk" integer, "ID_DeviseFk" integer, "IdEntiteFk" integer, "QteSignee" numeric, "CoutUnitaire" numeric, "ValeurMouvement" numeric, "StockApres" numeric, "ValeurApres" numeric, "OrigineCout" text, "EtatValorisation" text)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE o record;m record; q numeric:=0;v numeric:=0;cu numeric;sgn integer;known boolean:=true;arret integer:=0;costs jsonb:='{}';source_id integer;tag text;entity integer;origins jsonb:='{}';needed integer[]:=ARRAY[]::integer[];corrections integer[]:=ARRAY[]::integer[];
BEGIN
 SELECT a."IdEntiteFk" INTO entity FROM logistique."T_Article" a WHERE a."ID_Article"=p_article;
 SELECT * INTO o FROM logistique."T_ValorisationOuverture" x WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise;
 IF FOUND THEN q=o."QuantiteOuverture";v=q*o."CoutOuverture";known=o."CoutOuverture" IS NOT NULL;arret=o."ID_MvtArrete";costs=o."CoutsAnterieurs";END IF;
 -- Préparer les liens réellement utilisés dans cet historique, une fois par article/devise.
 -- Le calcul est relu après un futur retour : son coût d’origine sera alors mis en cache.
 WITH child_commands AS (SELECT DISTINCT x."ID_cmdFk" AS child FROM logistique."T_Mouvement" x WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise AND x."ID_cmdFk" IS NOT NULL),
 links AS (SELECT r."ID_CommandeRetourFk" AS child,r."ID_CommandeOrigineFk" AS origin,0 AS priority FROM logistique."T_RetourBon" r JOIN child_commands c ON c.child=r."ID_CommandeRetourFk"
 UNION ALL SELECT i."ID_CommandeAnnulationFk",i."ID_CommandeCorrectionFk",1 FROM logistique."T_InventaireLigne" i WHERE i."ID_ArticleFk"=p_article AND i."ID_CommandeAnnulationFk" IS NOT NULL
 UNION ALL SELECT child."ID_Commande",dispatch."ID_Commande",2
 FROM logistique."T_Commande" child JOIN logistique."T_Commande" dispatch ON dispatch."ID_TransfertDepotFk"=child."ID_TransfertDepotFk" AND dispatch."OperationTransfert"='expedition'
 WHERE child."OperationTransfert" IN('reception','retour')),
 chosen AS (SELECT DISTINCT ON (x.child) x.child,x.origin FROM links x ORDER BY x.child,x.priority)
 SELECT coalesce(jsonb_object_agg(x.child::text,to_jsonb((SELECT y."ID_Mvt" FROM logistique."T_Mouvement" y WHERE y."ID_cmdFk"=x.origin AND y."ID_ArticleFk"=p_article AND y."ID_DeviseFk"=p_devise ORDER BY y."ID_Mvt" LIMIT 1))),'{}'::jsonb) INTO origins FROM chosen x;
 SELECT coalesce(array_agg(DISTINCT x.value::integer) FILTER(WHERE x.value IS NOT NULL),ARRAY[]::integer[]) INTO needed FROM jsonb_each_text(origins) x;
 SELECT coalesce(array_agg(DISTINCT i."ID_CommandeCorrectionFk") FILTER(WHERE i."ID_CommandeCorrectionFk" IS NOT NULL),ARRAY[]::integer[]) INTO corrections FROM logistique."T_InventaireLigne" i WHERE i."ID_ArticleFk"=p_article;
 FOR m IN SELECT x.*,g."AbrGenerique" AS sens FROM logistique."T_Mouvement" x JOIN referentiel."T_Generique" g ON g."ID_Generique"=x."ID_TypeMvtFk"
  WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise ORDER BY x."ID_Mvt" LOOP
  "ID_Mvt"=m."ID_Mvt";"ID_ArticleFk"=p_article;"ID_DeviseFk"=p_devise;"IdEntiteFk"=entity;
  sgn=CASE WHEN m.sens ILIKE 'entr%' THEN 1 WHEN m.sens ILIKE 'sort%' THEN -1 ELSE 0 END;
  "QteSignee"=m."QteMvt"*sgn;cu=NULL;tag=NULL;
  IF m."ID_Mvt"<=arret THEN
   "CoutUnitaire"=(costs->>m."ID_Mvt"::text)::numeric;"ValeurMouvement"="QteSignee"*"CoutUnitaire";"StockApres"=NULL;"ValeurApres"=NULL;
   "OrigineCout"='Avant arrêté';"EtatValorisation"=CASE WHEN "CoutUnitaire" IS NULL THEN 'Historique non valorisé' ELSE 'Coût conservé' END;RETURN NEXT;CONTINUE;
  END IF;
  source_id=(origins->>m."ID_cmdFk"::text)::integer;
  IF origins ? coalesce(m."ID_cmdFk"::text,'') THEN
   -- Un lien sans mouvement source reste sans coût, sans repli sur le prix commercial.
   cu=(costs->>source_id::text)::numeric;tag='Coût du mouvement d’origine';
  ELSIF sgn=1 THEN
   -- Un gain d’inventaire utilise le coût moyen, une réception son prix d’achat réel.
   IF m."ID_cmdFk"=ANY(corrections) THEN cu=CASE WHEN q>0 THEN v/q ELSE NULL END;tag='Correction d’inventaire';
   ELSE cu=m."PUMvt";tag='Prix d’achat de réception';END IF;
  ELSIF sgn=-1 THEN cu=CASE WHEN q>0 THEN v/q ELSE NULL END;tag='CUMP avant sortie';
  ELSE cu=0;tag='Sans effet de stock';END IF;
  IF NOT known OR cu IS NULL OR cu<0 OR cu::text IN ('NaN','Infinity','-Infinity') THEN known=false;END IF;
  IF known THEN v=v+"QteSignee"*cu;END IF;
  q=q+"QteSignee";
  IF q<0 OR (known AND v< -0.000000000001) THEN known=false;END IF;
  IF q=0 THEN v=0;known=true;END IF;
  IF known AND cu IS NOT NULL AND m."ID_Mvt"=ANY(needed) THEN costs=jsonb_set(costs,ARRAY[m."ID_Mvt"::text],to_jsonb(cu));END IF;
  "CoutUnitaire"=CASE WHEN known THEN cu ELSE NULL END;"ValeurMouvement"=CASE WHEN known THEN round("QteSignee"*cu,2) ELSE NULL END;
  "StockApres"=q;"ValeurApres"=CASE WHEN known THEN round(v,12) ELSE NULL END;"OrigineCout"=tag;
  "EtatValorisation"=CASE WHEN known THEN 'Calculé' WHEN o."CoutOuverture" IS NULL AND arret>0 THEN 'À initialiser' ELSE 'Coût à vérifier' END;
  RETURN NEXT;
 END LOOP;
END $$;

CREATE OR REPLACE VIEW logistique."V_ConsoMensuelleDevise" AS
 SELECT "ID_ArticleFk" AS "ID_Article",
    "NomArticle",
    (date_trunc('month'::text, "DateMvt"))::date AS "Mois",
    sum(
        CASE
            WHEN ("SigneStock" = '-1'::integer) THEN COALESCE("QteMvt", (0)::numeric)
            ELSE (0)::numeric
        END) AS "ConsoMensuelle",
    (sum(
        CASE
            WHEN ("SigneStock" = '-1'::integer) THEN COALESCE("MontantMvt", (0)::numeric)
            ELSE (0)::numeric
        END))::numeric(14,2) AS "ValeurConsoMensuelle",
    "ID_DeviseFk",
    "DeviseCode",
    "DeviseLibelle",
    jsonb_build_array(jsonb_build_object('id', "ID_DeviseFk", 'code', "DeviseCode", 'label', "DeviseLibelle", 'value', ((sum(
        CASE
            WHEN ("SigneStock" = '-1'::integer) THEN COALESCE("MontantMvt", (0)::numeric)
            ELSE (0)::numeric
        END))::numeric(14,2))::text, 'count', count(*) FILTER (WHERE ("SigneStock" = '-1'::integer)))) AS "MontantsParDevise"
   FROM logistique."V_MouvementStock" v
  WHERE ("DateMvt" IS NOT NULL) AND NOT logistique.fn_bon_transfert(v."ID_cmdFk")
  GROUP BY "ID_ArticleFk", "NomArticle", ((date_trunc('month'::text, "DateMvt"))::date), "ID_DeviseFk", "DeviseCode", "DeviseLibelle";

CREATE OR REPLACE VIEW logistique."V_ConsoMensuelle" AS
 SELECT source."ID_Article",
    source."NomArticle",
    source."Mois",
    source."ConsoMensuelle",
    source."ValeurConsoMensuelle",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    source."MontantsParDevise",
    r."IdEntiteFk"
   FROM (( SELECT d."ID_Article",
            d."NomArticle",
            d."Mois",
            sum(d."ConsoMensuelle") AS "ConsoMensuelle",
            (
                CASE
                    WHEN (count(*) = 1) THEN min(d."ValeurConsoMensuelle")
                    ELSE NULL::numeric
                END)::numeric(14,2) AS "ValeurConsoMensuelle",
                CASE
                    WHEN (count(*) = 1) THEN min(d."ID_DeviseFk")
                    ELSE NULL::integer
                END AS "ID_DeviseFk",
                CASE
                    WHEN (count(*) = 1) THEN min(d."DeviseCode")
                    ELSE NULL::text
                END AS "DeviseCode",
                CASE
                    WHEN (count(*) = 1) THEN min(d."DeviseLibelle")
                    ELSE NULL::text
                END AS "DeviseLibelle",
            jsonb_agg((d."MontantsParDevise" -> 0) ORDER BY d."DeviseCode", d."ID_DeviseFk") AS "MontantsParDevise"
           FROM logistique."V_ConsoMensuelleDevise" d
          GROUP BY d."ID_Article", d."NomArticle", d."Mois") source
     LEFT JOIN logistique."T_Article" r ON ((r."ID_Article" = source."ID_Article")));

-- Les définitions du socle attesté sont conservées sans recopier ni simplifier
-- leurs jointures métier. Les clés dépôt sont ajoutées à la fin : les références
-- par nom et l’ordre des anciennes colonnes restent strictement identiques.
DO $$ DECLARE r record;definition text;extra text;BEGIN
 FOR r IN SELECT * FROM (VALUES
  ('V_Commande','T_Commande','ID_Commande'),
  ('V_CommandeDetail','T_Commande','ID_Commande'),
  ('V_Mouvement','T_Mouvement','ID_Mvt'),
  ('V_MouvementStock','T_Mouvement','ID_Mvt'),
  ('V_Inventaire','T_Inventaire','ID_Inventaire')) AS v(view_name,table_name,key_name)
 LOOP
  SELECT rtrim(rtrim(pg_get_viewdef(format('logistique.%I',r.view_name)::regclass,true)),';') INTO definition;
  extra=CASE WHEN r.view_name='V_Commande' THEN ',source."ID_TransfertDepotFk",source."OperationTransfert"' ELSE '' END;
  EXECUTE format('CREATE OR REPLACE VIEW logistique.%I AS SELECT historique.*,source."ID_DepotFk"%s FROM (%s) historique LEFT JOIN logistique.%I source ON source.%I=historique.%I',r.view_name,extra,definition,r.table_name,r.key_name,r.key_name);
 END LOOP;
END $$;

CREATE VIEW logistique."V_StockTransit" AS
 SELECT t."IdEntiteFk",t."ID_TransfertDepot",t."CodeTransfert",t."ID_DepotSourceFk",t."ID_DepotDestinationFk",t."ID_DeviseFk",l."ID_ArticleFk",l."QteTransit",
 (SELECT c."CoutUnitaire" FROM logistique."T_Commande" b JOIN logistique."V_CoutMouvement" c ON c."ID_Mvt"=(SELECT m."ID_Mvt" FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=b."ID_Commande" AND m."ID_ArticleFk"=l."ID_ArticleFk") WHERE b."ID_TransfertDepotFk"=t."ID_TransfertDepot" AND b."OperationTransfert"='expedition') AS "CoutUnitaireSource"
 FROM logistique."T_TransfertDepot" t JOIN logistique."V_TransfertDepotLigne" l ON l."ID_TransfertDepotFk"=t."ID_TransfertDepot" WHERE l."QteTransit">0;

COMMENT ON TABLE logistique."T_Depot" IS 'Lieux physiques de stockage de chaque entreprise ; le principal accueille uniquement le rattachement initial des historiques sans créer de mouvement.';
COMMENT ON TABLE logistique."T_TransfertDepot" IS 'Transferts internes à une entreprise : demande, réservation, expédition puis réceptions ou retours partiels ; ni vente ni facture ni écriture de caisse.';
COMMENT ON TABLE logistique."T_TransfertDepotLigne" IS 'Articles et quantités demandées du transfert ; lignes figées après validation, quantités exécutées dérivées exclusivement des bons liés.';
COMMENT ON TABLE logistique."T_TransfertDepotAction" IS 'Journal immuable des actions et preuves de rejeu acteur/UUID/empreinte ; chaque expédition, réception ou retour possède un seul bon et ses mouvements existants.';
COMMENT ON VIEW logistique."V_StockDepot" IS 'Stock physique signé par dépôt et article, réservé par les transferts validés non expédiés et disponible ; transit exclu, sans addition entre unités différentes.';
COMMENT ON VIEW logistique."V_StockLotDepot" IS 'Quantité physique de chaque lot dans chaque dépôt, dérivée des ventilations des mouvements ; aucun solde copié dans le lot.';
COMMENT ON VIEW logistique."V_TransfertDepotLigne" IS 'Suivi de chaque article transféré : quantités demandées, expédiées, reçues, retournées, écart clos et transit ; aucun compteur d’exécution modifiable.';
COMMENT ON VIEW logistique."V_TransfertDepot" IS 'Registre de transferts internes, dépôts, états référencés et suivi agrégé ; les totaux hétérogènes sont indicatifs et les quantités par article font foi.';
COMMENT ON VIEW logistique."V_Depot" IS 'Dépôts autorisables par entreprise et synthèse physique ; ne pas interpréter une somme entre unités différentes comme une mesure homogène.';
COMMENT ON VIEW logistique."V_ReservationLotDepot" IS 'Quantités de lots engagées par les transferts validés non expédiés, au grain dépôt/article/lot ; réserve distincte du stock physique.';
COMMENT ON VIEW logistique."V_StockTransit" IS 'Propriété de l’entreprise momentanément hors dépôt : transit et coût exact de la sortie source, distincts du stock physique disponible.';
-- Le rôle HTTP reste append-only sur les preuves, même si les droits par défaut
-- du propriétaire accordent les mutations ordinaires aux nouvelles tables métier.
DO $$ BEGIN
 IF EXISTS(SELECT FROM pg_roles WHERE rolname='sauverndeko_runtime') THEN
  REVOKE UPDATE,DELETE ON logistique."T_TransfertDepotAction" FROM sauverndeko_runtime;
 END IF;
END $$;
COMMENT ON FUNCTION logistique.fn_preparer_depot() IS 'Attribue le code DEP-ID à la création et conserve propriétaire et création ; incrémente la révision à chaque modification.';
COMMENT ON FUNCTION logistique.fn_depot_principal(integer) IS 'Résout sans écriture le dépôt principal actif d’une entreprise.';
COMMENT ON FUNCTION logistique.fn_creer_depot_principal() IS 'Initialise un dépôt principal pour une nouvelle entreprise ; ne crée aucun article ou mouvement.';
COMMENT ON FUNCTION logistique.fn_etat_transfert(text) IS 'Résout les identifiants des états centraux du transfert à partir de leur code stable, sans identifiant numérique codé en dur.';
COMMENT ON FUNCTION logistique.fn_bon_transfert(integer) IS 'Classe un document interne par sa FK de transfert, jamais par son code ou sa référence descriptive.';
COMMENT ON FUNCTION logistique.fn_verifier_depot_document() IS 'Impose le dépôt physique de l’entreprise et hérite du bon sur le mouvement ; refuse le déplacement d’un historique et les sens internes incompatibles.';
COMMENT ON FUNCTION logistique.fn_proteger_transfert() IS 'Verrouille et vérifie entreprise, dépôts, états et unités ; conserve les lignes validées et les actions immuables.';
COMMENT ON FUNCTION logistique.fn_controler_stock_depots() IS 'Vérification différée sérialisée par article : aucun dépôt ou lot négatif, aucune réservation excessive, somme physique égale au miroir global.';
COMMENT ON FUNCTION logistique.fn_controler_transfert_complet() IS 'Contrôle différé des bons et preuves liés, des quantités en transit et de la conservation des lots expédiés lors des réceptions et retours.';
COMMENT ON FUNCTION logistique.fn_bloquer_document_transfert() IS 'Fige les bons, lignes, mouvements et ventilations internes dès que leur action est inscrite ; les compensations créent un autre bon.';
COMMENT ON FUNCTION logistique.fn_transfert_non_commercial() IS 'Interdit la facturation, la restitution commerciale et la correction d’inventaire d’un transfert interne.';
COMMENT ON FUNCTION logistique.fn_controler_depot_actif() IS 'Refuse la désactivation d’un dépôt avec stock, réservations, transfert ouvert ou comptage non validé.';
COMMENT ON FUNCTION logistique.fn_cout_mouvements(integer,integer) IS 'CUMP historique : les réceptions et retours de transfert reprennent le coût exact de leur sortie source ; le transit est valorisé séparément.';
COMMENT ON VIEW logistique."V_ConsoMensuelleDevise" IS 'Consommation article/mois/devise hors transferts internes, qui ne constituent pas des besoins consommés.';
DO $$ DECLARE r record;description text;BEGIN
 FOR r IN SELECT c.relname,a.attname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
  WHERE n.nspname='logistique' AND c.relkind IN('r','p','v','m') AND (c.relname IN('T_Depot','T_TransfertDepot','T_TransfertDepotLigne','T_TransfertDepotAction','V_Depot','V_StockDepot','V_StockLotDepot','V_TransfertDepot','V_TransfertDepotLigne','V_StockTransit','V_ReservationLotDepot') OR a.attname IN('ID_DepotFk','ID_TransfertDepotFk','OperationTransfert'))
 LOOP
  description=CASE r.attname
   WHEN 'StockPhysique' THEN 'Quantité réellement présente dans le dépôt, issue des mouvements signés ; transit exclu.'
   WHEN 'StockReserve' THEN 'Quantité réservée par les transferts validés et non encore expédiés.'
   WHEN 'StockDisponible' THEN 'Stock physique diminué des réservations, lots inactifs et péremptions bloquées ; minimum zéro, dans l’unité propre à l’article.'
   WHEN 'StockIndisponible' THEN 'Stock des lots inactifs ou périmés bloqués par la politique de l’entreprise ; pas une réservation ni un transit.'
   WHEN 'StockSansLot' THEN 'Stock physique restant après ventilation des lots du dépôt.'
   WHEN 'QteTransit' THEN 'Expédié moins reçu, retourné et écart clos ; indisponible dans les dépôts.'
   WHEN 'QteEcart' THEN 'Quantité en transit soldée par un constat motivé ; déjà sortie, sans second mouvement.'
   WHEN 'QteRecue' THEN 'Quantité des bons de réception uniques au dépôt destinataire.'
   WHEN 'QteRetournee' THEN 'Quantité des bons de retour de transit au dépôt source.'
   WHEN 'QteExpediee' THEN 'Quantité de l’unique bon de sortie du transfert.'
   WHEN 'QteDemandee' THEN 'Quantité positive demandée dans l’unité de stock de l’article.'
   WHEN 'ID_DepotFk' THEN 'Dépôt physique de l’entreprise du document, hérité par ses mouvements et conservé après exécution.'
   WHEN 'ID_TransfertDepotFk' THEN 'Lien durable au transfert interne ; ne vaut ni commande commerciale, ni paiement.'
   WHEN 'OperationTransfert' THEN 'Rôle physique du bon interne : expedition source, reception destination ou retour source.'
   WHEN 'RequestId' THEN 'Clé UUID d’une action, unique avec son auteur ; réutilisation uniquement avec la même empreinte.'
   WHEN 'PayloadHash' THEN 'Empreinte SHA-256 du contenu canonique de la demande permettant de refuser un rejeu différent.'
   WHEN 'Lots' THEN 'Ventilation demandée par numéro de lot, péremption et Quantite ; ne modifie aucun solde avant expédition.'
   WHEN 'Lignes' THEN 'Détail des écarts clos : tableau ID_ArticleFk/Quantite ; autres quantités issues des documents liés.'
   WHEN 'ID_UserFk' THEN 'Compte auteur de l’enregistrement ou de l’action ; les permissions sont contrôlées par le service.'
   WHEN 'IdEntiteFk' THEN 'Entreprise propriétaire durable ; aucune opération entre entreprises dans ce périmètre.'
   WHEN 'ID_EtatFk' THEN 'État central du transfert dans referentiel.T_Generique, distinct de ses quantités exécutées.'
   WHEN 'ID_DeviseFk' THEN 'Devise historique de valorisation ; aucun taux de conversion implicite.'
   WHEN 'Principal' THEN 'Dépôt actif proposé par défaut pour les opérations de cette entreprise.'
   WHEN 'Version' THEN 'Révision monotone de contrôle des modifications simultanées.'
   WHEN 'CreeLe' THEN 'Date et heure de création conservées, avec fuseau horaire.'
   WHEN 'ModifieLe' THEN 'Date et heure de dernière modification, avec fuseau horaire.'
   WHEN 'DateAction' THEN 'Date et heure de l’action immuable, avec fuseau horaire.'
   WHEN 'CoutUnitaireSource' THEN 'Coût CUMP exact du mouvement expédié ; NULL lorsque le coût d’origine reste inconnu.'
   ELSE 'Information '||r.attname||' du suivi multi-dépôts ('||r.relname||'), conservée au grain de son enregistrement.' END;
  EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',r.relname,r.attname,description);
 END LOOP;
 FOR r IN SELECT c.relname,t.tgname FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN('logistique','systeme') AND (t.tgname IN('depot_preparer','entite_depot_principal','a00_depot_document','a00_depot_mouvement','a00_depot_inventaire','transfert_integrite','transfert_ligne_integrite','transfert_action_integrite','depot_stock_mouvement','depot_stock_lot','depot_stock_reservation','depot_stock_transfert','transfert_complet','transfert_action_complete','transfert_bon_complet','aa_transfert_bon_immutable','aa_transfert_ligne_immutable','aa_transfert_mouvement_immutable','aa_transfert_lot_immutable','a00_facture_sans_transfert','a00_retour_sans_transfert','a00_inventaire_sans_transfert','depot_desactivation'))
 LOOP EXECUTE format('COMMENT ON TRIGGER %I ON %I.%I IS %L',r.tgname,CASE WHEN r.relname='T_Entite' THEN 'systeme' ELSE 'logistique' END,r.relname,'Garde multi-dépôts : '||r.tgname||'. Effets de stock exclusivement produits par les procédures des bons existantes.');END LOOP;
END $$;

CREATE FUNCTION logistique.fn_depot_lot_selection() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT FROM logistique."T_Mouvement" m JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=NEW."ID_LotArticleFk"
  WHERE m."ID_Mvt"=NEW."ID_MvtFk" AND logistique.fn_effet_type_bon(m."ID_TypeMvtFk")=-1 AND NOT l."Actif") THEN
  RAISE EXCEPTION 'Ce lot est inactif ; une sortie physique exige un lot autorisé.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER depot_lot_selection BEFORE INSERT OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.fn_depot_lot_selection();
COMMENT ON FUNCTION logistique.fn_depot_lot_selection() IS 'Refuse la sélection d’un lot inactif pour une sortie ; les blocages de péremption et dérogations existants restent applicables.';
COMMENT ON TRIGGER depot_lot_selection ON logistique."T_MouvementLot" IS 'Conserve la distinction entre présence physique et lot autorisé à la sortie, y compris pour un transfert.';

CREATE FUNCTION logistique.fn_principal_depot_complet() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 PERFORM 1 FROM systeme."T_Entite" WHERE "IdEntite"=NEW."IdEntiteFk" FOR NO KEY UPDATE;
 IF (SELECT count(*) FROM logistique."T_Depot" WHERE "IdEntiteFk"=NEW."IdEntiteFk" AND "Principal" AND "Actif")<>1 THEN
  RAISE EXCEPTION 'Chaque entreprise doit conserver exactement un dépôt principal actif.' USING ERRCODE='23514';END IF;
 RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER depot_principal_complet AFTER INSERT OR UPDATE ON logistique."T_Depot" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.fn_principal_depot_complet();
COMMENT ON FUNCTION logistique.fn_principal_depot_complet() IS 'Conserve exactement un dépôt principal actif par entreprise ; une bascule entre dépôts est autorisée dans une transaction unique.';
COMMENT ON TRIGGER depot_principal_complet ON logistique."T_Depot" IS 'Vérifie après toutes les lignes la présence du dépôt principal actif ; empêche sa disparition par un changement isolé.';

CREATE VIEW logistique."V_AuditStockDepot" AS
 SELECT a."ID_Article",a."CodeArticleInterne",a."NomArticle",s."StockPhysique" AS "StockArticle",coalesce(m.qty,0) AS "StockMouvements",
 s."StockPhysique"-coalesce(m.qty,0) AS "Ecart",coalesce(m.n,0) AS "N_Mouvements",coalesce(m.entree,0) AS "QteEntree",coalesce(m.sortie,0) AS "QteSortie",
 s."StockPhysique"=coalesce(m.qty,0) AS "EstStockCoherent",CASE WHEN s."StockPhysique"=coalesce(m.qty,0) THEN 'Cohérent' ELSE 'Écart' END AS "EtatAuditStock",
 a."ID_DeviseFk",logistique.fn_code_devise(g."AbrGenerique") AS "DeviseCode",g."NomGenerique"::text AS "DeviseLibelle",s."IdEntiteFk",s."ID_DepotFk"
 FROM logistique."V_StockDepot" s JOIN logistique."T_Article" a ON a."ID_Article"=s."ID_ArticleFk" LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=a."ID_DeviseFk"
 LEFT JOIN LATERAL(SELECT sum(x."QteMvt"*logistique.fn_effet_type_bon(x."ID_TypeMvtFk")) AS qty,count(*) AS n,
 sum(x."QteMvt") FILTER(WHERE logistique.fn_effet_type_bon(x."ID_TypeMvtFk")=1) AS entree,
 sum(x."QteMvt") FILTER(WHERE logistique.fn_effet_type_bon(x."ID_TypeMvtFk")=-1) AS sortie
 FROM logistique."T_Mouvement" x WHERE x."ID_DepotFk"=s."ID_DepotFk" AND x."ID_ArticleFk"=s."ID_ArticleFk") m ON true;
CREATE VIEW logistique."V_ConsoMensuelleDepot" AS
 SELECT v."ID_ArticleFk" AS "ID_Article",v."NomArticle",date_trunc('month',v."DateMvt")::date AS "Mois",
 coalesce(sum(v."QteMvt") FILTER(WHERE v."SigneStock"=-1),0) AS "ConsoMensuelle",
 coalesce(sum(v."MontantMvt") FILTER(WHERE v."SigneStock"=-1),0)::numeric(14,2) AS "ValeurConsoMensuelle",
 v."ID_DeviseFk",v."DeviseCode",v."DeviseLibelle",
 jsonb_build_array(jsonb_build_object('id',v."ID_DeviseFk",'code',v."DeviseCode",'label',v."DeviseLibelle",'value',coalesce(sum(v."MontantMvt") FILTER(WHERE v."SigneStock"=-1),0)::text,'count',count(*) FILTER(WHERE v."SigneStock"=-1))) AS "MontantsParDevise",
 v."IdEntiteFk",v."ID_DepotFk"
 FROM logistique."V_MouvementStock" v WHERE v."DateMvt" IS NOT NULL AND NOT logistique.fn_bon_transfert(v."ID_cmdFk")
 GROUP BY v."ID_ArticleFk",v."NomArticle",date_trunc('month',v."DateMvt")::date,v."ID_DeviseFk",v."DeviseCode",v."DeviseLibelle",v."IdEntiteFk",v."ID_DepotFk";
CREATE VIEW logistique."V_CouvertureStockDepot" AS
 WITH conso AS (SELECT "ID_ArticleFk","ID_DepotFk",sum("QteMvt") FILTER(WHERE "SigneStock"=-1) AS qty FROM logistique."V_MouvementStock" v
 WHERE "DateMvt">=CURRENT_DATE-interval '6 months' AND "DateMvt"<CURRENT_DATE+interval '1 day' AND NOT logistique.fn_bon_transfert(v."ID_cmdFk") GROUP BY 1,2)
 SELECT a."ID_Article",a."CodeArticleInterne",a."NomArticle",u."AbrGenerique" AS "AbrUnite",s."StockDisponible" AS "StockActuel",coalesce(c.qty,0) AS "Conso6Mois",round(coalesce(c.qty,0)/6,2) AS "ConsoMoyMensuelle",
 round(s."StockDisponible"/nullif(c.qty/6,0),1) AS "CouvertureMois",
 CASE WHEN coalesce(c.qty,0)=0 THEN 'Aucune consommation récente' WHEN s."StockDisponible"/nullif(c.qty/6,0)<1 THEN 'Critique' WHEN s."StockDisponible"/nullif(c.qty/6,0)<3 THEN 'Faible' ELSE 'Correcte' END AS "EtatCouverture",
 a."ID_DeviseFk",logistique.fn_code_devise(g."AbrGenerique") AS "DeviseCode",g."NomGenerique"::text AS "DeviseLibelle",s."IdEntiteFk",s."ID_DepotFk"
 FROM logistique."V_StockDepot" s JOIN logistique."T_Article" a ON a."ID_Article"=s."ID_ArticleFk" LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk"
 LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=a."ID_DeviseFk" LEFT JOIN conso c ON c."ID_ArticleFk"=s."ID_ArticleFk" AND c."ID_DepotFk"=s."ID_DepotFk";
COMMENT ON VIEW logistique."V_AuditStockDepot" IS 'Contrôle au grain article/dépôt des projections et du journal physique ; ne constitue pas un comptage physique indépendant.';
COMMENT ON VIEW logistique."V_ConsoMensuelleDepot" IS 'Consommation mensuelle au grain article/dépôt/devise, hors transferts internes ; aucune conversion ni addition entre unités.';
COMMENT ON VIEW logistique."V_CouvertureStockDepot" IS 'Couverture du disponible du dépôt selon six mois de sorties hors transferts, divisés par six ; NULL sans consommation et stock physique distinct.';
CREATE VIEW logistique."V_ArticlePeremptionDepot" AS
 WITH lots AS (
 SELECT s."ID_DepotFk",s."ID_ArticleFk",sum(s."StockLot") AS total,
 coalesce(sum(s."StockLot") FILTER(WHERE s."StockLot">0 AND l."DatePeremptionLot"<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date),0) AS perime,
 coalesce(sum(s."StockLot") FILTER(WHERE s."StockLot">0 AND l."DatePeremptionLot">=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AND l."DatePeremptionLot"<=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date+coalesce(a."NbreJoursAlerteArticle",e."AlertePeremptionJours"::integer,30)),0) AS proche,
 coalesce(sum(s."StockLot") FILTER(WHERE s."StockLot">0 AND l."DatePeremptionLot" IS NULL),0) AS sansdate,
 min(l."DatePeremptionLot") FILTER(WHERE s."StockLot">0) AS dateproche,
 count(*) FILTER(WHERE s."StockLot">0 AND l."DatePeremptionLot"<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date) AS lotsperimes,
 count(*) FILTER(WHERE s."StockLot">0 AND l."DatePeremptionLot">=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AND l."DatePeremptionLot"<=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date+coalesce(a."NbreJoursAlerteArticle",e."AlertePeremptionJours"::integer,30)) AS lotsproches
 FROM logistique."V_StockLotDepot" s JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=s."ID_LotArticleFk"
 JOIN logistique."T_Article" a ON a."ID_Article"=s."ID_ArticleFk" JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk" GROUP BY s."ID_DepotFk",s."ID_ArticleFk"
 ), stocks AS (
 SELECT a."ID_Article",s."IdEntiteFk",s."ID_DepotFk",s."StockPhysique" AS "QteArticle",a."DatePeremptionArticle"::date AS generale,a."DatePeremptionAlerteArticle"::date AS alertegenerale,
 coalesce(a."NbreJoursAlerteArticle",e."AlertePeremptionJours"::integer,30) AS seuil,s."StockSansLot" AS sanslot,
 coalesce(l.perime,0) AS lotperime,coalesce(l.proche,0) AS lotproche,coalesce(l.sansdate,0) AS lotsansdate,l.dateproche,coalesce(l.lotsperimes,0) AS lotsperimes,coalesce(l.lotsproches,0) AS lotsproches
 FROM logistique."V_StockDepot" s JOIN logistique."T_Article" a ON a."ID_Article"=s."ID_ArticleFk" JOIN systeme."T_Entite" e ON e."IdEntite"=s."IdEntiteFk"
 LEFT JOIN lots l ON l."ID_DepotFk"=s."ID_DepotFk" AND l."ID_ArticleFk"=s."ID_ArticleFk"
 ), classement AS (
 SELECT stocks.*,
 lotperime+CASE WHEN generale<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date THEN sanslot ELSE 0 END AS perime,
 lotproche+CASE WHEN generale>=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AND (generale<=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date+seuil OR alertegenerale<=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date) THEN sanslot ELSE 0 END AS proche,
 lotsansdate+CASE WHEN generale IS NULL THEN sanslot ELSE 0 END AS sansdate,
 least(dateproche,CASE WHEN sanslot>0 THEN generale END) AS prochaine FROM stocks
 )
 SELECT "ID_Article","IdEntiteFk",perime AS "StockPerime",proche AS "StockProchePeremption",sansdate AS "StockSansDatePeremption",sanslot AS "StockSansLot",prochaine AS "DateProchainePeremption",lotsperimes AS "LotsPerimes",lotsproches AS "LotsProchesPeremption",seuil AS "SeuilAlerteJours",perime>0 AS "EstPerime",proche>0 AS "EstAlertePeremption",
 CASE WHEN perime>0 THEN 'Périmé' WHEN proche>0 THEN 'Alerte péremption' WHEN coalesce("QteArticle",0)<=0 THEN 'Sans stock' WHEN sansdate>0 THEN 'Non renseignée' ELSE 'Valide' END AS "EtatPeremption",
 prochaine-(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AS "JoursAvantPeremption",
 CASE WHEN perime>0 THEN 1 WHEN proche>0 THEN 2 WHEN sansdate>0 OR coalesce("QteArticle",0)<=0 THEN 4 ELSE 3 END AS "PrioritePeremption","ID_DepotFk" FROM classement;
COMMENT ON VIEW logistique."V_ArticlePeremptionDepot" IS 'Alertes de péremption réellement présentes dans chaque dépôt : lots et stock sans lot locaux, délais article ou entreprise, date métier de Kinshasa ; transit exclu.';
DO $$ DECLARE r record;BEGIN
 FOR r IN SELECT c.relname,a.attname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
 WHERE n.nspname='logistique' AND c.relname IN('V_AuditStockDepot','V_ConsoMensuelleDepot','V_CouvertureStockDepot','V_ReservationLotDepot','V_ArticlePeremptionDepot')
 LOOP EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',r.relname,r.attname,'Mesure '||r.attname||' au grain article et dépôt, dans son unité/devise historique ; '||r.relname||'.');END LOOP;
END $$;

CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS
 SELECT source."ID_Article",
    source."CodeArticleInterne",
    source."NomArticle",
    source."AbrUnite",
    source."StockActuel",
    source."Conso6Mois",
    source."ConsoMoyMensuelle",
    source."CouvertureMois",
    source."EtatCouverture",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk"
   FROM (( SELECT historique."ID_Article",
            historique."CodeArticleInterne",
            historique."NomArticle",
            historique."AbrUnite",
            historique."StockActuel",
            historique."Conso6Mois",
            historique."ConsoMoyMensuelle",
            historique."CouvertureMois",
            historique."EtatCouverture",
            source_1."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( WITH conso AS (
                         SELECT v."ID_ArticleFk",
                            sum(
                                CASE
                                    WHEN (v."SigneStock" = '-1'::integer) THEN COALESCE(v."QteMvt", (0)::numeric)
                                    ELSE (0)::numeric
                                END) AS conso_6m
                           FROM logistique."V_MouvementStock" v
                          WHERE NOT logistique.fn_bon_transfert(v."ID_cmdFk") AND ((v."DateMvt" >= (CURRENT_DATE - '6 mons'::interval)) AND (v."DateMvt" < (CURRENT_DATE + '1 day'::interval)))
                          GROUP BY v."ID_ArticleFk"
                        )
                 SELECT a."ID_Article",
                    a."CodeArticleInterne",
                    a."NomArticle",
                    a."AbrUnite",
                    a."QteArticle" AS "StockActuel",
                    COALESCE(conso.conso_6m, (0)::numeric) AS "Conso6Mois",
                    round((COALESCE(conso.conso_6m, (0)::numeric) / 6.0), 2) AS "ConsoMoyMensuelle",
                        CASE
                            WHEN (COALESCE(conso.conso_6m, (0)::numeric) = (0)::numeric) THEN NULL::numeric
                            ELSE round((a."QteArticle" / NULLIF((conso.conso_6m / 6.0), (0)::numeric)), 1)
                        END AS "CouvertureMois",
                        CASE
                            WHEN (COALESCE(conso.conso_6m, (0)::numeric) = (0)::numeric) THEN 'Aucune consommation récente'::text
                            WHEN (round((a."QteArticle" / NULLIF((conso.conso_6m / 6.0), (0)::numeric)), 1) < (1)::numeric) THEN 'Critique'::text
                            WHEN (round((a."QteArticle" / NULLIF((conso.conso_6m / 6.0), (0)::numeric)), 1) < (3)::numeric) THEN 'Faible'::text
                            ELSE 'Correcte'::text
                        END AS "EtatCouverture"
                   FROM (logistique."V_Article" a
                     LEFT JOIN conso ON ((conso."ID_ArticleFk" = a."ID_Article")))) historique
             LEFT JOIN logistique."T_Article" source_1 ON ((source_1."ID_Article" = historique."ID_Article")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Article" r ON ((r."ID_Article" = source."ID_Article")));
