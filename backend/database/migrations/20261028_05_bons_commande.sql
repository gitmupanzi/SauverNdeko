-- Bons de commande explicites, distincts des entrées et sorties physiques.
-- Aucun document, code, mouvement ou coût historique n'est réécrit.
BEGIN;
SET LOCAL lock_timeout='15s';
SET LOCAL statement_timeout='120s';
DO $precondition$
BEGIN
 IF current_database()<>'SauverNdeko' AND left(current_database(),17)<>'sauverndeko_test_' THEN RAISE EXCEPTION 'Base cible non autorisée.';END IF;
 IF to_regprocedure('logistique.fn_materialiser_stock_initial(integer,integer)') IS NULL OR NOT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='logistique' AND table_name='T_Commande' AND column_name='OrigineBon') THEN RAISE EXCEPTION 'Socle de stock initial 20261028_01 requis.';END IF;
 IF EXISTS(SELECT FROM information_schema.columns WHERE table_schema='logistique' AND table_name='V_Commande' AND column_name='NatureBon') THEN RAISE EXCEPTION 'Migration05 déjà installée : rejeu interdit.';END IF;
END $precondition$;

CREATE OR REPLACE FUNCTION logistique.fn_nature_type_bon(p_abbreviation text)
RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path=pg_catalog
AS $$ SELECT CASE WHEN upper(btrim(p_abbreviation))='CMD' THEN 'commande'
 WHEN p_abbreviation ILIKE 'entr%' THEN 'entree'
 WHEN p_abbreviation ILIKE 'sort%' THEN 'sortie' ELSE NULL END $$;
COMMENT ON FUNCTION logistique.fn_nature_type_bon(text) IS 'Classe une abréviation de type : CMD exact prépare une commande ; entr*/sort* constatent une opération physique. NULL désigne un type inconnu, jamais un bon neutre autorisé.';

CREATE OR REPLACE FUNCTION logistique.fn_nature_bon(p_type integer)
RETURNS text LANGUAGE sql STABLE PARALLEL SAFE SET search_path=pg_catalog
AS $$ SELECT logistique.fn_nature_type_bon(g."AbrGenerique")
 FROM referentiel."T_Generique" g WHERE g."ID_Generique"=p_type AND g."ID_CategorieGeneriqueFk"=64 $$;
COMMENT ON FUNCTION logistique.fn_nature_bon(integer) IS 'Nature métier du type du référentiel Type de commande : entree, sortie, commande ou NULL. Ne fige aucun identifiant de valeur CMD ; conserve la lecture des types historiques désactivés.';

CREATE OR REPLACE FUNCTION logistique.fn_effet_type_bon(p_type integer)
RETURNS smallint LANGUAGE sql STABLE PARALLEL SAFE SET search_path=pg_catalog
AS $$ SELECT CASE logistique.fn_nature_bon(p_type) WHEN 'entree' THEN 1 WHEN 'sortie' THEN -1 WHEN 'commande' THEN 0 ELSE NULL END::smallint $$;
COMMENT ON FUNCTION logistique.fn_effet_type_bon(integer) IS 'Effet stock du type connu : +1 entrée, -1 sortie, 0 pour CMD explicite. Un type absent ou inconnu retourne NULL et doit être refusé en écriture.';

DO $seed$
BEGIN
 IF NOT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=64 AND lower(btrim("NomCategorieGenerique"))='type de commande') THEN
  RAISE EXCEPTION 'Catégorie Type de commande attendue absente.' USING ERRCODE='23514';
 END IF;
 IF (SELECT count(*) FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=64 AND upper(btrim("AbrGenerique"))='CMD')>1 THEN
  RAISE EXCEPTION 'Le type CMD doit être unique.' USING ERRCODE='23514';
 END IF;
 IF NOT EXISTS(SELECT FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=64 AND upper(btrim("AbrGenerique"))='CMD') THEN
  INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(64,'Bon de commande','CMD',true);
 END IF;
END $seed$;
CREATE UNIQUE INDEX IF NOT EXISTS generique_type_cmd_unique ON referentiel."T_Generique"("ID_CategorieGeneriqueFk") WHERE "ID_CategorieGeneriqueFk"=64 AND upper(btrim("AbrGenerique"))='CMD';
COMMENT ON INDEX referentiel.generique_type_cmd_unique IS 'Une seule valeur CMD dans Type de commande ; l’identifiant est attribué par le référentiel et non figé dans les services.';

CREATE OR REPLACE FUNCTION logistique.fn_code_bon(p_id integer,p_type integer)
RETURNS character varying LANGUAGE plpgsql STABLE STRICT SET search_path=pg_catalog AS $$
DECLARE nature text:=logistique.fn_nature_bon(p_type);
BEGIN
 IF p_id IS NULL OR p_id<=0 OR nature IS NULL THEN RAISE EXCEPTION 'Identité ou type de bon inconnu.' USING ERRCODE='23514';END IF;
 RETURN CASE nature WHEN 'entree' THEN 'BE-' WHEN 'sortie' THEN 'BS-' WHEN 'commande' THEN 'CMD-' END||p_id::text;
END $$;
COMMENT ON FUNCTION logistique.fn_code_bon(integer,integer) IS 'Numéro court automatique des nouveaux documents : BE-ID, BS-ID et CMD-ID selon le type explicite du référentiel. Les numéros déjà émis restent inchangés.';


CREATE OR REPLACE PROCEDURE logistique.ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE op text:=upper(btrim(p_operation)); old_abr text; new_abr text; old_sign integer; new_sign integer; item record;
 prior_skip text:=coalesce(current_setting('logistique.skip_article_report_mvt',true),'off');
 prior_write text:=coalesce(current_setting('logistique.allow_t_mouvement_write',true),'off');
BEGIN
 IF op='DELETE' THEN RETURN; END IF;
 IF op NOT IN ('INSERT','UPDATE') OR op IS NULL THEN RAISE EXCEPTION 'Opération de commande inconnue.' USING ERRCODE='23514'; END IF;
 PERFORM logistique.fn_assert_generique_category(p_new_id_type_cmd,64,'Commande','ID_TypeCmdFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_statut_cmd,28,'Commande','ID_StatutCmdFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_condition_paiement,37,'Commande','ID_ConditionPaiementFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_mode_paiement,36,'Commande','ID_ModePaiementFk');
 SELECT "AbrGenerique" INTO new_abr FROM referentiel."T_Generique" WHERE "ID_Generique"=p_new_id_type_cmd AND "ID_CategorieGeneriqueFk"=64;
 new_sign:=CASE WHEN new_abr ILIKE 'entr%' THEN 1 WHEN new_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
 IF logistique.fn_nature_bon(p_new_id_type_cmd) IS NULL THEN RAISE EXCEPTION 'Type de bon inconnu.' USING ERRCODE='23514'; END IF;
 IF op='INSERT' OR p_old_id_type_cmd IS NOT DISTINCT FROM p_new_id_type_cmd THEN RETURN; END IF;
 IF logistique.fn_nature_bon(p_old_id_type_cmd)='commande' OR logistique.fn_nature_bon(p_new_id_type_cmd)='commande' THEN RAISE EXCEPTION 'Un bon de commande ne se convertit pas en mouvement physique ; créez un BE ou BS distinct.' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande) THEN RETURN; END IF;
 SELECT "AbrGenerique" INTO old_abr FROM referentiel."T_Generique" WHERE "ID_Generique"=p_old_id_type_cmd AND "ID_CategorieGeneriqueFk"=64;
 old_sign:=CASE WHEN old_abr ILIKE 'entr%' THEN 1 WHEN old_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
 IF old_sign=0 THEN RAISE EXCEPTION 'Ancien type inconnu : changement de sens impossible.' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article" IN
 (SELECT "ID_ArticleFk" FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande)
 ORDER BY a."ID_Article" FOR NO KEY UPDATE;
 PERFORM set_config('logistique.skip_article_report_mvt','on',true);
 FOR item IN SELECT "ID_ArticleFk" id,"QteCmdDetail"*(new_sign-old_sign) delta FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande ORDER BY "ID_ArticleFk"
 LOOP IF item.delta<>0 THEN CALL logistique.ps_update_qte_article(item.id,abs(item.delta),CASE WHEN item.delta>0 THEN '+' ELSE '-' END); END IF; END LOOP;
 PERFORM set_config('logistique.skip_article_report_mvt',prior_skip,true);
 PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
 UPDATE logistique."T_Mouvement" SET "ID_TypeMvtFk"=p_new_id_type_cmd WHERE "ID_cmdFk"=p_id_commande;
 PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
END;
$$;

COMMENT ON PROCEDURE logistique.ps_crud_commande(integer,integer,integer,integer,integer,integer,character varying) IS 'Valide les catégories et la nature explicite du bon : CMD ne produit aucun effet stock ; les changements physiques autorisés conservent le calcul net historique. Toute conversion vers ou depuis CMD est interdite.';

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
 op text := upper(btrim(p_operation)); old_type integer; new_type integer;
 old_abr text; new_abr text; old_sign integer := 0; new_sign integer := 0;
 item record; touched integer;
 prior_skip text := coalesce(current_setting('logistique.skip_article_report_mvt',true),'off');
 prior_write text := coalesce(current_setting('logistique.allow_t_mouvement_write',true),'off');
BEGIN

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

 IF op NOT IN ('INSERT','UPDATE','DELETE') OR op IS NULL THEN
  RAISE EXCEPTION 'Opération de ligne inconnue.' USING ERRCODE='23514';
 END IF;
 -- Le cas neutre est explicite ; l'absence de mouvement ne prouve jamais un CMD.
 IF op IN ('INSERT','UPDATE') AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk))='commande' THEN
  IF p_new_qte IS NULL OR p_new_qte<=0 OR p_new_pu IS NULL OR p_new_pu<0 THEN RAISE EXCEPTION 'Quantité positive et prix convenu non négatif requis.' USING ERRCODE='23514';END IF;
  IF op='UPDATE' AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_old_cmd_fk)) IS DISTINCT FROM 'commande' THEN RAISE EXCEPTION 'Déplacement entre commande et opération physique interdit.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=ANY(ARRAY[p_old_cmd_fk,p_new_cmd_fk])) THEN RAISE EXCEPTION 'Un bon de commande ne doit avoir aucun mouvement.' USING ERRCODE='23514';END IF;
  PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article"=ANY(ARRAY[p_old_article_fk,p_new_article_fk]) ORDER BY a."ID_Article" FOR NO KEY UPDATE;
  IF NOT EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_Article"=p_new_article_fk AND a."ValideArticle" IS TRUE) THEN RAISE EXCEPTION 'Article absent ou désactivé.' USING ERRCODE='23514';END IF;
  RETURN;
 END IF;
 IF op IN ('UPDATE','DELETE') AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_old_cmd_fk))='commande' THEN
  IF op='UPDATE' THEN RAISE EXCEPTION 'Déplacement entre commande et opération physique interdit.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=p_old_cmd_fk) THEN RAISE EXCEPTION 'Un bon de commande ne doit avoir aucun mouvement.' USING ERRCODE='23514';END IF;
  PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article"=p_old_article_fk FOR NO KEY UPDATE;
  RETURN;
 END IF;
 IF op IN ('UPDATE','DELETE') THEN
  IF p_old_qte IS NULL OR p_old_qte<=0 THEN
   RAISE EXCEPTION 'Ancienne quantité de ligne invalide.' USING ERRCODE='23514';
  END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO old_type,old_abr
  FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" AND g."ID_CategorieGeneriqueFk"=64
  WHERE c."ID_Commande"=p_old_cmd_fk;
  IF NOT FOUND THEN
   SELECT m."ID_TypeMvtFk",g."AbrGenerique" INTO old_type,old_abr
   FROM logistique."T_Mouvement" m JOIN referentiel."T_Generique" g ON g."ID_Generique"=m."ID_TypeMvtFk" AND g."ID_CategorieGeneriqueFk"=64
   WHERE m."ID_cmdFk"=p_old_cmd_fk AND m."ID_ArticleFk"=p_old_article_fk;
  END IF;
  old_sign := CASE WHEN old_abr ILIKE 'entr%' THEN 1 WHEN old_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF old_sign=0 THEN RAISE EXCEPTION 'Ancien type de mouvement inconnu.' USING ERRCODE='23514'; END IF;
 END IF;
 IF op IN ('INSERT','UPDATE') THEN
  IF p_new_qte IS NULL OR p_new_qte<=0 OR p_new_pu<0 THEN
   RAISE EXCEPTION 'Quantité entière positive et prix non négatif requis.' USING ERRCODE='23514';
  END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO new_type,new_abr
  FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" AND g."ID_CategorieGeneriqueFk"=64
  WHERE c."ID_Commande"=p_new_cmd_fk;
  new_sign := CASE WHEN new_abr ILIKE 'entr%' THEN 1 WHEN new_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF new_sign=0 THEN RAISE EXCEPTION 'Nouveau type de mouvement inconnu.' USING ERRCODE='23514'; END IF;
 END IF;
 -- Une quantité modifiée applique le delta net : aucun stock négatif intermédiaire artificiel.
 PERFORM 1 FROM logistique."T_Article" a
 WHERE a."ID_Article"=ANY(ARRAY[p_old_article_fk,p_new_article_fk])
 ORDER BY a."ID_Article" FOR NO KEY UPDATE;
 PERFORM set_config('logistique.skip_article_report_mvt','on',true);
 FOR item IN
  SELECT id,sum(delta) delta FROM (VALUES
   (p_old_article_fk,CASE WHEN op IN ('UPDATE','DELETE') THEN -old_sign*p_old_qte ELSE 0 END),
   (p_new_article_fk,CASE WHEN op IN ('INSERT','UPDATE') THEN new_sign*p_new_qte ELSE 0 END)
  ) x(id,delta) WHERE id IS NOT NULL GROUP BY id ORDER BY id
 LOOP
  IF item.delta<>0 THEN
   CALL logistique.ps_update_qte_article(item.id,abs(item.delta),CASE WHEN item.delta>0 THEN '+' ELSE '-' END);
  END IF;
 END LOOP;
 PERFORM set_config('logistique.skip_article_report_mvt',prior_skip,true);
 PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
 IF op='UPDATE' AND p_old_cmd_fk=p_new_cmd_fk AND p_old_article_fk=p_new_article_fk THEN
  IF p_old_qte IS DISTINCT FROM p_new_qte OR p_old_pu IS DISTINCT FROM p_new_pu THEN
   UPDATE logistique."T_Mouvement" SET "QteMvt"=p_new_qte,"PUMvt"=coalesce(p_new_pu,0),"ID_TypeMvtFk"=new_type
   WHERE "ID_cmdFk"=p_old_cmd_fk AND "ID_ArticleFk"=p_old_article_fk;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'La ligne doit posséder exactement un mouvement source.' USING ERRCODE='23514'; END IF;
  END IF;
 ELSE
  IF op IN ('UPDATE','DELETE') THEN
   DELETE FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=p_old_cmd_fk AND "ID_ArticleFk"=p_old_article_fk;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'Mouvement source absent ou dupliqué.' USING ERRCODE='23514'; END IF;
  END IF;
  IF op IN ('INSERT','UPDATE') THEN
   INSERT INTO logistique."T_Mouvement"("ID_TypeMvtFk","ID_ArticleFk","ID_cmdFk","DateHeureAutoMvt","DateMvt","QteMvt","PUMvt")
   VALUES(new_type,p_new_article_fk,p_new_cmd_fk,now(),now(),p_new_qte,coalesce(p_new_pu,0));
  END IF;
 END IF;
 PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
END;
$$;

COMMENT ON PROCEDURE logistique.ps_crud_commandedetail(integer,integer,numeric,numeric,integer,integer,numeric,numeric,character varying) IS 'Lignes CMD : quantité et prix convenu valides, aucun stock, mouvement, lot ni coût ; les totaux restent calculés par les triggers de transition. Préserve les flux physiques et le stock initial sans double mouvement.';

CREATE OR REPLACE FUNCTION logistique.tr_numero_commande() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
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
  IF NEW."ID_TypeCmdFk" IS DISTINCT FROM OLD."ID_TypeCmdFk" AND (logistique.fn_nature_bon(OLD."ID_TypeCmdFk")='commande' OR logistique.fn_nature_bon(NEW."ID_TypeCmdFk")='commande') THEN RAISE EXCEPTION 'Nature CMD immuable ; créez un BE ou BS distinct.' USING ERRCODE='23514';END IF;
  IF NEW."ID_Commande" IS DISTINCT FROM OLD."ID_Commande" OR NEW."CodeCmd" IS DISTINCT FROM OLD."CodeCmd" THEN RAISE EXCEPTION 'Identite et code du bon immuables.' USING ERRCODE='23514';END IF;
  IF NEW."ID_TypeCmdFk" IS DISTINCT FROM OLD."ID_TypeCmdFk" AND OLD."CodeCmd" ~ '^(BE|BS)-' AND logistique.fn_code_bon(NEW."ID_Commande",NEW."ID_TypeCmdFk") IS DISTINCT FROM OLD."CodeCmd" THEN RAISE EXCEPTION 'Le sens du bon est conserve avec son numero; creez un nouveau bon.' USING ERRCODE='23514';END IF;
  IF NEW."CodeFacture" IS DISTINCT FROM OLD."CodeFacture" THEN
   IF NULLIF(btrim(OLD."CodeFacture"),'') IS NOT NULL OR NEW."CodeFacture" IS DISTINCT FROM logistique.fn_code_facture(NEW."ID_Commande") OR NOT EXISTS(SELECT FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=NEW."ID_Commande" AND f."CodeFacture"=NEW."CodeFacture") THEN RAISE EXCEPTION 'Numero de facture automatique et immuable.' USING ERRCODE='23514';END IF;
  END IF;
 END IF;
 RETURN NEW;
END $$;

COMMENT ON FUNCTION logistique.tr_numero_commande() IS 'Attribue BE-/BS-/CMD- aux nouvelles identités, conserve les codes historiques et interdit toute conversion vers ou depuis CMD, même sans ligne. Les factures gardent leur numérotation dédiée.';


CREATE OR REPLACE FUNCTION logistique.tr_commande_sans_stock() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE nature text;
BEGIN
 IF TG_OP='DELETE' THEN
  IF logistique.fn_nature_bon(OLD."ID_TypeCmdFk")='commande' AND EXISTS(SELECT FROM logistique."T_CommandeDetail" d WHERE d."ID_CmdFk"=OLD."ID_Commande") THEN
   RAISE EXCEPTION 'Retirez les articles du bon de commande avant sa suppression.' USING ERRCODE='23514';
  END IF;
  RETURN OLD;
 END IF;
 nature:=logistique.fn_nature_bon(NEW."ID_TypeCmdFk");
 IF nature IS NULL THEN RAISE EXCEPTION 'Type de bon inconnu ; choisissez un type du référentiel.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."ID_TypeCmdFk" IS DISTINCT FROM OLD."ID_TypeCmdFk" AND (nature='commande' OR logistique.fn_nature_bon(OLD."ID_TypeCmdFk")='commande') THEN
  RAISE EXCEPTION 'Nature CMD immuable ; créez un BE ou BS distinct.' USING ERRCODE='23514';
 END IF;
 IF nature='commande' AND (NEW."OrigineBon" IS NOT NULL OR NEW."DateFacture" IS NOT NULL OR NEW."DateHeureAutoFacture" IS NOT NULL
  OR nullif(btrim(NEW."CodeFacture"),'') IS NOT NULL OR nullif(btrim(NEW."UrlFacture"),'') IS NOT NULL OR nullif(btrim(NEW."UrlBL"),'') IS NOT NULL
  OR nullif(btrim(NEW."StatusFacture"),'') IS NOT NULL OR NEW."ValideRemiseFacture" IS TRUE
  OR coalesce(NEW."MontantRegleFacture",0)<>0 OR coalesce(NEW."MontantResteFacture",0)<>0) THEN
  RAISE EXCEPTION 'Une commande prépare des articles sans facture, règlement, livraison physique ni mouvement.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_commande_sans_stock() IS 'Garde SQL du bon : refuse les types inconnus, la conversion CMD/physique et la facturation/livraison de CMD. Pour supprimer un CMD, retirer ses lignes préalablement afin de conserver une classification explicite.';
DROP TRIGGER IF EXISTS a01_commande_sans_stock ON logistique."T_Commande";
CREATE TRIGGER a01_commande_sans_stock BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_commande_sans_stock();
COMMENT ON TRIGGER a01_commande_sans_stock ON logistique."T_Commande" IS 'Avant toute écriture d’en-tête, distingue la commande préparatoire des entrées/sorties et protège son identité et son absence de facturation.';

CREATE OR REPLACE FUNCTION logistique.tr_mouvement_physique() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE nature text; parent_nature text;
BEGIN
 nature:=logistique.fn_nature_bon(NEW."ID_TypeMvtFk");
 IF nature IS NULL OR nature='commande' THEN RAISE EXCEPTION 'Un mouvement exige une entrée ou sortie physique.' USING ERRCODE='23514';END IF;
 IF NEW."ID_cmdFk" IS NOT NULL THEN
  SELECT logistique.fn_nature_bon(c."ID_TypeCmdFk") INTO parent_nature FROM logistique."T_Commande" c WHERE c."ID_Commande"=NEW."ID_cmdFk" FOR NO KEY UPDATE;
  IF parent_nature IS DISTINCT FROM nature THEN RAISE EXCEPTION 'Mouvement incompatible avec la nature du bon ; aucun mouvement pour CMD.' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_mouvement_physique() IS 'Refuse tout mouvement CMD, inconnu ou lié à un parent CMD, même avec le drapeau interne d’écriture activé et un type physique falsifié. Vérifie le sens commun du parent verrouillé et du mouvement.';
DROP TRIGGER IF EXISTS a01_mouvement_physique ON logistique."T_Mouvement";
CREATE TRIGGER a01_mouvement_physique BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_mouvement_physique();
COMMENT ON TRIGGER a01_mouvement_physique ON logistique."T_Mouvement" IS 'Défense SQL indépendante du service : seul un mouvement réel de même nature que son bon peut être enregistré.';

CREATE OR REPLACE FUNCTION referentiel.fn_guard_sens_stock() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE old_nature text; new_nature text;
BEGIN
 IF OLD."ID_CategorieGeneriqueFk"=64 AND (
  EXISTS(SELECT FROM logistique."T_Commande" WHERE "ID_TypeCmdFk"=OLD."ID_Generique") OR EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_TypeMvtFk"=OLD."ID_Generique")) THEN
  old_nature:=logistique.fn_nature_type_bon(OLD."AbrGenerique");new_nature:=logistique.fn_nature_type_bon(NEW."AbrGenerique");
  IF NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM 64 OR new_nature IS DISTINCT FROM old_nature THEN
   RAISE EXCEPTION 'La nature d’un type de bon déjà utilisé ne peut pas changer.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION referentiel.fn_guard_sens_stock() IS 'Préserve la nature exacte des types utilisés : CMD ne peut pas devenir un autre type de signe zéro. Les libellés peuvent évoluer en conservant la catégorie et la nature métier.';
COMMENT ON TRIGGER tr_guard_sens_stock ON referentiel."T_Generique" IS 'Protège les sens physiques et la nature CMD des types déjà utilisés, sans figer les libellés ni les nouveaux identifiants de valeur.';



-- Conserver ordre, types et dépendances des colonnes historiques ; ajouter NatureBon.
DO $views$
DECLARE view_name text; definition text; projection text; field record; expression text; kind_expression text;
BEGIN
 FOREACH view_name IN ARRAY ARRAY['V_Commande','V_CommandeDetail','V_CommandeOverview'] LOOP
  definition:=regexp_replace(pg_get_viewdef(format('logistique.%I',view_name)::regclass,true),';[[:space:]]*$','');
  kind_expression:='logistique.fn_nature_bon(source."ID_TypeCmdFk")';projection:='';
  FOR field IN SELECT a.attname,format_type(a.atttypid,a.atttypmod) AS sql_type FROM pg_attribute a WHERE a.attrelid=format('logistique.%I',view_name)::regclass AND a.attnum>0 AND NOT a.attisdropped ORDER BY a.attnum LOOP
   IF field.attname='NatureBon' THEN CONTINUE;END IF;
   expression:=format('source.%I',field.attname);
   IF field.attname='EtatPaiement' THEN expression:=format('CASE WHEN %s=''commande'' THEN ''Sans facturation'' ELSE %s END',kind_expression,expression);
   ELSIF field.attname='EstPaiementEnRetard' THEN expression:=format('CASE WHEN %s=''commande'' THEN false ELSE %s END',kind_expression,expression);
   ELSIF field.attname=ANY(ARRAY['MontantRegleFactureCalc','MontantResteFactureCalc','TotalRegleReel','ResteReel','JoursAvantEcheance','StockAvantLigneTheorique']) THEN expression:=format('CASE WHEN %s=''commande'' THEN NULL ELSE %s END',kind_expression,expression);
   END IF;
   projection:=projection||CASE WHEN projection='' THEN '' ELSE ',' END||format('(%s)::%s AS %I',expression,field.sql_type,field.attname);
  END LOOP;
  EXECUTE format('CREATE OR REPLACE VIEW logistique.%I AS SELECT %s,%s AS "NatureBon" FROM (%s) source',view_name,projection,kind_expression,definition);
  EXECUTE format('COMMENT ON VIEW logistique.%I IS %L',view_name,'Projection métier commune des bons et lignes : NatureBon distingue CMD sans effet stock des BE/BS. Une commande ne porte ni dette ni alerte de facture manquante ; totaux exacts conservés.');
  EXECUTE format('COMMENT ON COLUMN logistique.%I."NatureBon" IS %L',view_name,'entree ou sortie pour un document physique ; commande pour CMD explicite du référentiel ; NULL si un ancien type est inconnu.');
  FOR field IN SELECT a.attname FROM pg_attribute a WHERE a.attrelid=format('logistique.%I',view_name)::regclass AND a.attnum>0 AND NOT a.attisdropped AND a.attname=ANY(ARRAY['MontantRegleFactureCalc','MontantResteFactureCalc','TotalRegleReel','ResteReel','JoursAvantEcheance','StockAvantLigneTheorique']) LOOP
   EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',view_name,field.attname,'Valeur de suivi d’une opération physique ou facturée ; NULL pour CMD, qui ne produit ni stock, règlement, dette ou échéance de facture réelle.');
  END LOOP;
 END LOOP;
END $views$;
COMMENT ON COLUMN logistique."V_Commande"."EtatPaiement" IS 'État réel de facturation ; Sans facturation pour CMD, qui ne constitue ni une facture impayée ni une dette.';
COMMENT ON COLUMN logistique."V_CommandeOverview"."EtatPaiement" IS 'État de paiement partagé avec V_Commande ; CMD reste Sans facturation.';
COMMENT ON COLUMN logistique."V_Commande"."EstPaiementEnRetard" IS 'Alerte sur une facture échue ; toujours faux pour un bon de commande CMD.';
COMMENT ON COLUMN logistique."V_CommandeDetail"."StockAvantLigneTheorique" IS 'Stock avant l’effet physique de la ligne ; NULL pour CMD, qui ne modifie et ne réserve aucun stock.';
COMMENT ON TABLE logistique."T_Commande" IS 'Documents d’articles typés par le référentiel : BE entrée physique, BS sortie physique, CMD préparation sans stock. Identités et numéros émis immuables ; facturation dédiée aux sorties autorisées.';
COMMENT ON COLUMN logistique."T_Commande"."ID_TypeCmdFk" IS 'Valeur Type de commande dans le référentiel : entr*/sort* pour les mouvements physiques, CMD exact pour le bon de commande sans stock, facture ni restitution. Une nature inconnue est refusée.';
COMMENT ON TABLE logistique."T_CommandeDetail" IS 'Articles et prix convenus d’un bon ; totaux exacts partagés. BE/BS pilotent un seul mouvement par ligne ; CMD ne produit aucun stock, lot, mouvement ou coût.';

COMMIT;
