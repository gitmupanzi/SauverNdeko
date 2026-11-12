-- Stock initial documenté et numérotation typée des nouveaux bons.
-- Aucun document existant n'est renuméroté, aucun mouvement historique supprimé.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
SET LOCAL search_path=pg_catalog;
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base hors perimetre';END IF;
 IF to_regprocedure('logistique.fn_reserver_identite_commande()') IS NULL THEN RAISE EXCEPTION 'Numerotation existante requise';END IF;
 IF EXISTS(SELECT FROM information_schema.columns WHERE table_schema='logistique' AND table_name='T_Commande' AND column_name='OrigineBon') THEN RAISE EXCEPTION 'Migration deja installee ou partielle';END IF;
END $$;
LOCK TABLE logistique."T_Article",logistique."T_Commande",logistique."T_CommandeDetail",logistique."T_Mouvement" IN SHARE ROW EXCLUSIVE MODE;
ALTER TABLE logistique."T_Article"
 ADD COLUMN "CreationRequestId" uuid,
 ADD COLUMN "CreationPayloadHash" varchar(64),
 ADD CONSTRAINT article_creation_demande_coherente CHECK(("CreationRequestId" IS NULL AND "CreationPayloadHash" IS NULL) OR ("CreationRequestId" IS NOT NULL AND "CreationPayloadHash" IS NOT NULL AND "ID_UserFK" IS NOT NULL AND "CreationPayloadHash" ~ '^[a-f0-9]{64}$'));
CREATE UNIQUE INDEX article_creation_demande_unique ON logistique."T_Article"("IdEntiteFk","ID_UserFK","CreationRequestId") WHERE "CreationRequestId" IS NOT NULL;
ALTER TABLE logistique."T_Commande"
 ADD COLUMN "OrigineBon" text,
 ADD COLUMN "ID_ArticleInitialFk" integer,
 ADD CONSTRAINT bon_article_initial_fk FOREIGN KEY("ID_ArticleInitialFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 ADD CONSTRAINT bon_origine_initiale_coherente CHECK(("OrigineBon" IS NULL AND "ID_ArticleInitialFk" IS NULL) OR ("OrigineBon" IS NOT NULL AND "OrigineBon" IN ('stock_initial','reprise_mouvement') AND "ID_ArticleInitialFk" IS NOT NULL));
CREATE UNIQUE INDEX bon_stock_initial_unique ON logistique."T_Commande"("ID_ArticleInitialFk") WHERE "OrigineBon"='stock_initial';

CREATE FUNCTION logistique.fn_code_bon(p_id integer,p_type integer) RETURNS varchar
 LANGUAGE plpgsql STABLE STRICT SET search_path=pg_catalog AS $$
DECLARE abbreviation text;
BEGIN
 IF p_id<=0 THEN RAISE EXCEPTION 'Identite positive requise' USING ERRCODE='23514';END IF;
 SELECT "AbrGenerique" INTO abbreviation FROM referentiel."T_Generique" WHERE "ID_Generique"=p_type AND "ID_CategorieGeneriqueFk"=64;
 RETURN CASE WHEN abbreviation ILIKE 'entr%' THEN 'BE-' WHEN abbreviation ILIKE 'sort%' THEN 'BS-' ELSE 'cmd-' END||p_id::text;
END $$;

CREATE OR REPLACE FUNCTION logistique.tr_numero_commande() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE expected_code varchar;
BEGIN
 IF TG_OP='INSERT' THEN
  expected_code=logistique.fn_code_bon(NEW."ID_Commande",NEW."ID_TypeCmdFk");
  IF expected_code IS NULL OR logistique.fn_identite_commande_deja_utilisee(NEW."ID_Commande") THEN RAISE EXCEPTION 'Cette identite de bon a deja ete utilisee.' USING ERRCODE='23514';END IF;
  IF NULLIF(btrim(NEW."CodeCmd"),'') IS NOT NULL AND NEW."CodeCmd"<>expected_code THEN RAISE EXCEPTION 'Le code du bon est attribue automatiquement.' USING ERRCODE='23514';END IF;
  NEW."CodeCmd"=expected_code;
  IF NULLIF(btrim(NEW."CodeFacture"),'') IS NOT NULL THEN RAISE EXCEPTION 'La facture est emise apres le bon.' USING ERRCODE='23514';END IF;
  NEW."CodeFacture"=NULL;
 ELSE
  IF NEW."ID_Commande" IS DISTINCT FROM OLD."ID_Commande" OR NEW."CodeCmd" IS DISTINCT FROM OLD."CodeCmd" THEN RAISE EXCEPTION 'Identite et code du bon immuables.' USING ERRCODE='23514';END IF;
  IF NEW."ID_TypeCmdFk" IS DISTINCT FROM OLD."ID_TypeCmdFk" AND OLD."CodeCmd" ~ '^(BE|BS)-' AND logistique.fn_code_bon(NEW."ID_Commande",NEW."ID_TypeCmdFk") IS DISTINCT FROM OLD."CodeCmd" THEN RAISE EXCEPTION 'Le sens du bon est conserve avec son numero; creez un nouveau bon.' USING ERRCODE='23514';END IF;
  IF NEW."CodeFacture" IS DISTINCT FROM OLD."CodeFacture" THEN
   IF NULLIF(btrim(OLD."CodeFacture"),'') IS NOT NULL OR NEW."CodeFacture" IS DISTINCT FROM logistique.fn_code_facture(NEW."ID_Commande") OR NOT EXISTS(SELECT FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=NEW."ID_Commande" AND f."CodeFacture"=NEW."CodeFacture") THEN RAISE EXCEPTION 'Numero de facture automatique et immuable.' USING ERRCODE='23514';END IF;
  END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER a0_numero_commande ON logistique."T_Commande";
CREATE TRIGGER a0_numero_commande BEFORE INSERT OR UPDATE OF "ID_Commande","CodeCmd","CodeFacture","ID_TypeCmdFk" ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_numero_commande();

-- Le numéro demeure lié à l'identité globale non réutilisable, quel que soit son préfixe.
CREATE OR REPLACE FUNCTION logistique.fn_identites_audit(p_document jsonb) RETURNS numeric[]
 LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $$
DECLARE result numeric[]:=ARRAY[]::numeric[]; raw text; digits text; key text;
BEGIN
 IF jsonb_typeof(p_document)<>'object' THEN RETURN result;END IF;
 FOREACH key IN ARRAY ARRAY['ID_Commande','ID_CommandeFk','ID_CommandeRetourFk','CodeCmd','CodeFacture'] LOOP
  raw=p_document->>key;
  IF raw IS NULL THEN CONTINUE;END IF;
  IF key='CodeCmd' THEN
   IF raw ~* '^C_[0-9]+$' THEN digits=substr(raw,3);
   ELSIF raw ~* '^cmd-[0-9]+$' THEN digits=substr(raw,5);
   ELSIF raw ~* '^(BE|BS)-[0-9]+$' THEN digits=substr(raw,4);ELSE CONTINUE;END IF;
  ELSIF key='CodeFacture' THEN
   IF raw ~* '^F_[0-9]+$' THEN digits=substr(raw,3);
   ELSIF raw ~* '^fac-[0-9]+$' THEN digits=substr(raw,5);ELSE CONTINUE;END IF;
  ELSE
   IF raw !~ '^[0-9]+$' THEN CONTINUE;END IF;digits=raw;
  END IF;
  digits=ltrim(digits,'0');
  IF digits='' OR length(digits)>1000 THEN CONTINUE;END IF;
  result=array_append(result,digits::numeric);
 END LOOP;
 SELECT coalesce(array_agg(DISTINCT x ORDER BY x),ARRAY[]::numeric[]) INTO result FROM unnest(result) x;
 RETURN result;
END $$;
REINDEX INDEX systeme.audit_document_identites_old_gin;
REINDEX INDEX systeme.audit_document_identites_new_gin;

CREATE OR REPLACE FUNCTION logistique.tr_audit_numero_document() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE payload jsonb;
BEGIN
 IF TG_TABLE_NAME='T_Commande' THEN payload=jsonb_build_object('ID_Commande',NEW."ID_Commande",'CodeCmd',NEW."CodeCmd");
 ELSE payload=jsonb_build_object('ID_Facture',NEW."ID_Facture",'ID_CommandeFk',NEW."ID_CommandeFk",'CodeFacture',NEW."CodeFacture");END IF;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","IdEntiteFk") VALUES('logistique.'||TG_TABLE_NAME,'DOCUMENT_NUMBER',payload,NEW."IdEntiteFk");
 RETURN NEW;
END $$;

CREATE FUNCTION logistique.tr_bon_initial_protection() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE parent record; armed text:=current_setting('logistique.stock_initial_article',true);
BEGIN
 IF TG_TABLE_NAME IN ('T_Facture','T_RetourBon') THEN
  IF EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."OrigineBon" IS NOT NULL AND c."ID_Commande"=CASE WHEN TG_TABLE_NAME='T_Facture' THEN (to_jsonb(NEW)->>'ID_CommandeFk')::integer ELSE (to_jsonb(NEW)->>'ID_CommandeOrigineFk')::integer END) THEN RAISE EXCEPTION 'Un stock initial ou une reprise ne constitue pas une vente ou un retour commercial.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 ELSIF TG_TABLE_NAME='T_Article' THEN
  IF TG_OP='UPDATE' AND ((NEW."CreationRequestId",NEW."CreationPayloadHash") IS DISTINCT FROM (OLD."CreationRequestId",OLD."CreationPayloadHash") OR OLD."CreationRequestId" IS NOT NULL AND NEW."ID_UserFK" IS DISTINCT FROM OLD."ID_UserFK") THEN RAISE EXCEPTION 'Identifiant et auteur de creation immuables.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 ELSIF TG_TABLE_NAME='T_Commande' THEN
  IF TG_OP='INSERT' THEN
   IF NEW."OrigineBon" IS NOT NULL AND (armed IS DISTINCT FROM NEW."ID_ArticleInitialFk"::text OR NOT EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_Article"=NEW."ID_ArticleInitialFk" AND a."IdEntiteFk"=NEW."IdEntiteFk")) THEN RAISE EXCEPTION 'Origine du stock reservee a la procedure.' USING ERRCODE='23514';END IF;
   RETURN NEW;
  END IF;
  IF TG_OP='UPDATE' AND (NEW."OrigineBon",NEW."ID_ArticleInitialFk") IS DISTINCT FROM (OLD."OrigineBon",OLD."ID_ArticleInitialFk") THEN RAISE EXCEPTION 'Origine du bon immuable.' USING ERRCODE='23514';END IF;
  IF OLD."OrigineBon" IS NOT NULL AND armed IS DISTINCT FROM OLD."ID_ArticleInitialFk"::text THEN RAISE EXCEPTION 'Le bon de stock initial est conserve; utilisez un bon correcteur.' USING ERRCODE='23514';END IF;
 ELSE
  SELECT * INTO parent FROM logistique."T_Commande" WHERE "ID_Commande"=CASE WHEN TG_OP='DELETE' THEN OLD."ID_CmdFk" ELSE NEW."ID_CmdFk" END;
  IF parent."OrigineBon" IS NOT NULL AND (armed IS DISTINCT FROM parent."ID_ArticleInitialFk"::text OR TG_OP<>'INSERT' OR NEW."ID_ArticleFk"<>parent."ID_ArticleInitialFk") THEN RAISE EXCEPTION 'La ligne de stock initial est conservee; utilisez un bon correcteur.' USING ERRCODE='23514';END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;
CREATE TRIGGER a00_bon_initial_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();
CREATE TRIGGER a00_ligne_initiale_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();
CREATE TRIGGER a00_article_creation_immuable BEFORE UPDATE OF "CreationRequestId","CreationPayloadHash","ID_UserFK" ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();
CREATE TRIGGER a00_stock_initial_facture BEFORE INSERT OR UPDATE ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();
CREATE TRIGGER a00_stock_initial_retour BEFORE INSERT OR UPDATE ON logistique."T_RetourBon" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();

-- Réutilise la procédure de lignes. Le cas initial est unique et ne réapplique
-- pas une quantité déjà portée par INSERT Article (ou par un mouvement repris).
DO $patch_line$
DECLARE definition text; marker text; branch text;
BEGIN
 SELECT pg_get_functiondef('logistique.ps_crud_commandedetail(integer,integer,numeric,numeric,integer,integer,numeric,numeric,character varying)'::regprocedure) INTO definition;
 marker='BEGIN';
 branch=$branch$
 IF op='INSERT' AND EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk AND c."OrigineBon" IN ('stock_initial','reprise_mouvement')) THEN
  IF current_setting('logistique.stock_initial_article',true) IS DISTINCT FROM p_new_article_fk::text THEN RAISE EXCEPTION 'Creation de stock initial hors procedure.' USING ERRCODE='23514';END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO new_type,new_abr FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" WHERE c."ID_Commande"=p_new_cmd_fk AND c."ID_ArticleInitialFk"=p_new_article_fk;
  IF new_type IS NULL OR p_new_qte<=0 OR p_new_pu<0 THEN RAISE EXCEPTION 'Stock initial invalide.' USING ERRCODE='23514';END IF;
  PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
  IF nullif(current_setting('logistique.stock_initial_mouvement',true),'') IS NOT NULL THEN
   UPDATE logistique."T_Mouvement" SET "ID_cmdFk"=p_new_cmd_fk WHERE "ID_Mvt"=current_setting('logistique.stock_initial_mouvement')::integer AND "ID_cmdFk" IS NULL AND "ID_ArticleFk"=p_new_article_fk AND "ID_TypeMvtFk"=new_type AND "QteMvt"=p_new_qte AND "PUMvt" IS NOT DISTINCT FROM p_new_pu;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'Mouvement historique modifie ou deja rattache.' USING ERRCODE='23514';END IF;
  ELSE
   INSERT INTO logistique."T_Mouvement"("ID_TypeMvtFk","ID_ArticleFk","ID_cmdFk","DateHeureAutoMvt","DateMvt","QteMvt","PUMvt") SELECT new_type,p_new_article_fk,p_new_cmd_fk,clock_timestamp(),c."DateCmd",p_new_qte,p_new_pu FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk;
  END IF;
  PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
  RETURN;
 END IF;
 $branch$;
 EXECUTE regexp_replace(definition,'\mBEGIN\M','BEGIN'||E'\n'||branch);
END $patch_line$;

CREATE FUNCTION logistique.fn_materialiser_stock_initial(p_article integer,p_mouvement integer DEFAULT NULL) RETURNS integer LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE a record;m logistique."T_Mouvement"%ROWTYPE;num record;kind integer;command_id integer;qty numeric;price numeric;business_date timestamp;origin text;prior_article text:=coalesce(current_setting('logistique.stock_initial_article',true),'');prior_movement text:=coalesce(current_setting('logistique.stock_initial_mouvement',true),'');
BEGIN
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=p_article FOR NO KEY UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Article absent.' USING ERRCODE='23503';END IF;
 IF p_mouvement IS NULL THEN
  SELECT "ID_Commande" INTO command_id FROM logistique."T_Commande" WHERE "ID_ArticleInitialFk"=p_article AND "OrigineBon"='stock_initial';
  IF FOUND THEN RETURN command_id;END IF;
  qty=a."QteArticle";price=a."PUArticle";business_date=coalesce(a."DateHeureAuto"::timestamp,clock_timestamp()::timestamp);origin='stock_initial';
  IF coalesce(qty,0)=0 THEN RETURN NULL;END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=p_article) THEN RAISE EXCEPTION 'Stock deja historise: rapprochez les mouvements existants.' USING ERRCODE='23514';END IF;
  SELECT g."ID_Generique" INTO kind FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ID_CategorieGeneriqueFk"=64 AND g."AbrGenerique" ILIKE 'entr%' AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE ORDER BY g."ID_Generique" LIMIT 1;
 ELSE
  SELECT * INTO m FROM logistique."T_Mouvement" WHERE "ID_Mvt"=p_mouvement AND "ID_ArticleFk"=p_article FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Mouvement absent.' USING ERRCODE='23503';END IF;
  IF m."ID_cmdFk" IS NOT NULL THEN RETURN m."ID_cmdFk";END IF;
  qty=m."QteMvt";price=m."PUMvt";business_date=m."DateMvt";kind=m."ID_TypeMvtFk";origin='reprise_mouvement';
 END IF;
 IF qty IS NULL OR qty<=0 OR price IS NULL OR price<0 OR kind IS NULL THEN RAISE EXCEPTION 'Quantite, prix d achat et type requis pour le stock initial.' USING ERRCODE='23514';END IF;
 PERFORM set_config('logistique.stock_initial_article',p_article::text,true);
 PERFORM set_config('logistique.stock_initial_mouvement',coalesce(p_mouvement::text,''),true);
 SELECT * INTO num FROM logistique.fn_reserver_identite_commande();
 INSERT INTO logistique."T_Commande"("ID_Commande","ID_TypeCmdFk","ID_UserFk","IdEntiteFk","ID_DeviseFk","DateCmd","DateHeureAutoCmd","RefCmd","ObsCmd","OrigineBon","ID_ArticleInitialFk")
 VALUES(num."ID_Commande",kind,CASE WHEN p_mouvement IS NULL THEN a."ID_UserFK" END,a."IdEntiteFk",coalesce(m."ID_DeviseFk",a."ID_DeviseFk"),business_date,clock_timestamp(),CASE WHEN p_mouvement IS NULL THEN 'Création depuis Articles / Stock initial' ELSE 'Reprise mouvement historique / '||p_mouvement::text END,CASE WHEN p_mouvement IS NULL THEN 'Création depuis Articles / Stock initial' ELSE 'Rattachement documentaire sans variation de stock. Auteur historique non prouvé; dates, prix et mouvement conservés.' END,origin,p_article)
 RETURNING "ID_Commande" INTO command_id;
 INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail","ObsCmdDetail") VALUES(command_id,p_article,qty,price,CASE WHEN p_mouvement IS NULL THEN 'Stock initial de la fiche article' ELSE 'Mouvement historique conservé #'||p_mouvement::text END);
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","IdEntiteFk") VALUES('logistique.T_Commande',CASE WHEN p_mouvement IS NULL THEN 'INITIAL_STOCK_DOCUMENT' ELSE 'HISTORICAL_STOCK_DOCUMENT' END,jsonb_build_object('ID_Commande',command_id,'ID_Article',p_article,'ID_Mvt',coalesce(p_mouvement,(SELECT "ID_Mvt" FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=command_id AND "ID_ArticleFk"=p_article)),'OrigineBon',origin,'AuteurOrigineProuve',p_mouvement IS NULL),a."IdEntiteFk");
 PERFORM set_config('logistique.stock_initial_article',prior_article,true);
 PERFORM set_config('logistique.stock_initial_mouvement',prior_movement,true);
 RETURN command_id;
END $$;

CREATE OR REPLACE FUNCTION logistique.tr_crud_article_after() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF coalesce(current_setting('logistique.skip_article_report_mvt',true),'off')='on' THEN RETURN NEW;END IF;
 IF TG_OP='INSERT' THEN
  IF coalesce(NEW."QteArticle",0)>0 THEN PERFORM logistique.fn_materialiser_stock_initial(NEW."ID_Article");END IF;
 ELSIF NEW."QteArticle" IS DISTINCT FROM OLD."QteArticle" THEN RAISE EXCEPTION 'Utilisez un bon de stock motive pour modifier les quantites.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

-- Un rattachement documentaire strict n'altère aucun élément d'un arrêté CUMP.
DO $patch_cost$
DECLARE definition text;
BEGIN
 SELECT pg_get_functiondef('logistique.tracer_source_cout()'::regprocedure) INTO definition;
 EXECUTE regexp_replace(definition,'\mBEGIN\M',$patch$BEGIN
 IF TG_OP='UPDATE' AND OLD."ID_cmdFk" IS NULL AND NEW."ID_cmdFk" IS NOT NULL AND (to_jsonb(NEW)-'ID_cmdFk')=(to_jsonb(OLD)-'ID_cmdFk') AND current_setting('logistique.stock_initial_mouvement',true)=OLD."ID_Mvt"::text AND EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."ID_Commande"=NEW."ID_cmdFk" AND c."OrigineBon"='reprise_mouvement' AND c."ID_ArticleInitialFk"=NEW."ID_ArticleFk") THEN
  INSERT INTO logistique."T_ValorisationEvenement"("ID_ArticleFk","IdEntiteFk","Operation","Motif","Avant","Apres") SELECT source_article."ID_Article",source_article."IdEntiteFk",'mouvement_update','Rattachement documentaire; mouvement, quantite, prix et arrete conserves',to_jsonb(OLD),to_jsonb(NEW) FROM logistique."T_Article" source_article WHERE source_article."ID_Article"=NEW."ID_ArticleFk";
  RETURN NEW;
 END IF;
 $patch$);
END $patch_cost$;

-- Reprise uniquement de mouvements prouvés. Pas de nouvelle quantité ni de
-- prétendue reconstitution d'un auteur ou d'un prix d'achat historique.
DO $reprise$ DECLARE m record;BEGIN
 FOR m IN SELECT "ID_Mvt","ID_ArticleFk" FROM logistique."T_Mouvement" WHERE "ID_cmdFk" IS NULL ORDER BY "ID_Mvt" LOOP
  PERFORM logistique.fn_materialiser_stock_initial(m."ID_ArticleFk",m."ID_Mvt");
 END LOOP;
END $reprise$;

DO $view_origin$ DECLARE definition text;BEGIN
 SELECT rtrim(pg_get_viewdef('logistique."V_Commande"'::regclass,true),E'\n ;') INTO definition;
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_Commande" AS SELECT source.*,c."OrigineBon",c."ID_ArticleInitialFk" FROM ('||definition||') source JOIN logistique."T_Commande" c ON c."ID_Commande"=source."ID_Commande"';
END $view_origin$;

COMMENT ON COLUMN logistique."T_Article"."CreationRequestId" IS 'UUID de creation fourni une seule fois par le formulaire, reserve au serveur pour rejouer une demande sans doubler article, bon ou mouvement; NULL pour les articles historiques.';
COMMENT ON COLUMN logistique."T_Article"."CreationPayloadHash" IS 'SHA256 du contenu de creation incluant lots et photo normalisee; permet de refuser la reutilisation du meme UUID avec un autre contenu.';
COMMENT ON COLUMN logistique."T_Commande"."OrigineBon" IS 'Origine technique distincte du sens Entree/Sortie: stock_initial pour creation depuis Articles, reprise_mouvement pour rattachement historique sans effet stock, NULL pour les autres flux existants.';
COMMENT ON COLUMN logistique."T_Commande"."ID_ArticleInitialFk" IS 'Article source du bon technique de stock initial ou de reprise documentaire; FK durable, jamais un fournisseur fictif.';
COMMENT ON COLUMN logistique."V_Commande"."OrigineBon" IS 'Origine durable distincte du type de bon: stock_initial, reprise_mouvement ou absence pour les autres flux.';
COMMENT ON COLUMN logistique."V_Commande"."ID_ArticleInitialFk" IS 'Article source du bon technique initial ou de reprise; les lignes et mouvements conservent leurs FK existantes.';
COMMENT ON FUNCTION logistique.fn_code_bon(integer,integer) IS 'Code court des nouveaux documents selon le type du referentiel: BE-ID entree, BS-ID sortie, cmd-ID autres commandes. Aucune renumerotation historique.';
COMMENT ON FUNCTION logistique.tr_numero_commande() IS 'Numerotation typee atomique a la creation; conserve les anciens codes et leur immutabilite ainsi que le code fac-ID emis par la facture.';
COMMENT ON FUNCTION logistique.fn_identites_audit(jsonb) IS 'Identites historiques indexables, y compris C_/cmd-/BE-/BS-/F_/fac- et zeros initiaux; les identites supprimees restent reservees.';
COMMENT ON FUNCTION logistique.tr_audit_numero_document() IS 'Trace chaque numero sous le proprietaire durable du document, independamment de la societe actuelle du createur; audits passes conserves.';
COMMENT ON FUNCTION logistique.tr_bon_initial_protection() IS 'Conserve demandes de creation et bons techniques initiaux; interdit suppression, facturation, restitution et modification silencieuse de leurs lignes.';
COMMENT ON FUNCTION logistique.fn_materialiser_stock_initial(integer,integer) IS 'Creation centrale sous verrou article d un bon initial, ligne et unique mouvement; ou rattachement d un mouvement orphelin prouve sans reappliquer le stock. Idempotent par source; aucun tiers fournisseur invente.';
COMMENT ON FUNCTION logistique.tr_crud_article_after() IS 'Apres creation avec quantite positive, materialise le stock initial par un bon entree et sa ligne; zero ne cree rien. Les modifications descriptives ne recreent rien; les ajustements directs sont refuses hors flux de lignes.';
COMMENT ON PROCEDURE logistique.ps_crud_commandedetail(integer,integer,numeric,numeric,integer,integer,numeric,numeric,character varying) IS 'Effet stock et mouvement unique des lignes; le seul flux interne de stock initial conserve la quantite deja inscrite et rattache les reprises sans double mouvement. Les autres lignes appliquent leur delta habituel.';
COMMENT ON FUNCTION logistique.tracer_source_cout() IS 'Trace les sources et protege les arretes confirmes; seule exception: rattachement documentaire strict d un mouvement orphelin sans changer identite, dates, quantite, prix ou devise.';
COMMENT ON TRIGGER a00_bon_initial_protection ON logistique."T_Commande" IS 'Origine reservee aux routines; bon initial conserve apres creation.';
COMMENT ON TRIGGER a00_ligne_initiale_protection ON logistique."T_CommandeDetail" IS 'Ligne du stock initial creee une seule fois et conservee; corrections par un nouveau bon.';
COMMENT ON TRIGGER a00_article_creation_immuable ON logistique."T_Article" IS 'UUID et empreinte de creation immuables.';
COMMENT ON TRIGGER a00_stock_initial_facture ON logistique."T_Facture" IS 'Refuse une facture commerciale issue d un stock initial ou d une reprise documentaire.';
COMMENT ON TRIGGER a00_stock_initial_retour ON logistique."T_RetourBon" IS 'Refuse un retour commercial sur un bon technique de stock initial ou de reprise.';
COMMENT ON TRIGGER tr_crud_article_after ON logistique."T_Article" IS 'Stock initial positif documente atomiquement; aucune entree fictive pour zero ni pour une edition descriptive.';
COMMENT ON TRIGGER a0_numero_commande ON logistique."T_Commande" IS 'Attribue BE/BS selon le sens initial et conserve identite, code et sens du prefixe; anciens codes inchanges.';
COMMENT ON INDEX logistique.article_creation_demande_unique IS 'Un UUID de creation par utilisateur et entreprise ne peut produire deux articles.';
COMMENT ON INDEX logistique.bon_stock_initial_unique IS 'Un seul bon automatique de creation par article; les reprises historiques distinctes restent tracables.';
COMMENT ON CONSTRAINT article_creation_demande_coherente ON logistique."T_Article" IS 'UUID et empreinte SHA256 presents ensemble ou tous deux absents sur les articles historiques.';
COMMENT ON CONSTRAINT bon_article_initial_fk ON logistique."T_Commande" IS 'Reference durable a l article dont le stock initial est documente; suppression physique interdite.';
COMMENT ON CONSTRAINT bon_origine_initiale_coherente ON logistique."T_Commande" IS 'Origine interne et article source obligatoirement associes.';
COMMIT;
