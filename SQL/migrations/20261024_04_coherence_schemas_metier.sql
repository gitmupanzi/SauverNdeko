-- 20261024_04 : cohérence des schémas partagés et du stock.
-- Vérifiée sur une copie de structure avec fixtures uniquement. Aucun DML métier.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
SELECT pg_advisory_xact_lock(hashtextextended('sauverndeko:20261024_04',0));

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commandedetail(
 IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric,
 IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric,
 IN p_operation character varying)
LANGUAGE plpgsql AS $body$
DECLARE
 op text := upper(btrim(p_operation)); old_type integer; new_type integer;
 old_abr text; new_abr text; old_sign integer := 0; new_sign integer := 0;
 item record; touched integer;
 prior_skip text := coalesce(current_setting('logistique.skip_article_report_mvt',true),'off');
 prior_write text := coalesce(current_setting('logistique.allow_t_mouvement_write',true),'off');
BEGIN
 IF op NOT IN ('INSERT','UPDATE','DELETE') OR op IS NULL THEN
  RAISE EXCEPTION 'Opération de ligne inconnue.' USING ERRCODE='23514';
 END IF;
 IF op IN ('UPDATE','DELETE') THEN
  IF p_old_qte IS NULL OR p_old_qte<=0 OR p_old_qte<>trunc(p_old_qte) THEN
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
  IF p_new_qte IS NULL OR p_new_qte<=0 OR p_new_qte<>trunc(p_new_qte) OR p_new_pu<0 THEN
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
   UPDATE logistique."T_Mouvement" SET "QteMvt"=p_new_qte::integer,"PUMvt"=coalesce(p_new_pu,0),"ID_TypeMvtFk"=new_type
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
   VALUES(new_type,p_new_article_fk,p_new_cmd_fk,now(),now(),p_new_qte::integer,coalesce(p_new_pu,0));
  END IF;
 END IF;
 PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
END;
$body$;
COMMENT ON PROCEDURE logistique.ps_crud_commandedetail(integer,integer,numeric,numeric,integer,integer,numeric,numeric,character varying)
 IS 'Applique le delta net de stock par article verrouillé ; INSERT/UPDATE/DELETE maintiennent un mouvement unique par ligne, son prix et sa quantité. Refuse le stock final négatif, les fractions et les prix négatifs. Les totaux sont recalculés par les triggers de fin d’instruction.';

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commande(
 IN p_id_commande integer,IN p_old_id_type_cmd integer,IN p_new_id_type_cmd integer,
 IN p_new_id_statut_cmd integer,IN p_new_id_condition_paiement integer,IN p_new_id_mode_paiement integer,
 IN p_operation character varying)
LANGUAGE plpgsql AS $body$
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
 IF new_sign=0 THEN RAISE EXCEPTION 'Une commande exige un type Entrée ou Sortie.' USING ERRCODE='23514'; END IF;
 IF op='INSERT' OR p_old_id_type_cmd IS NOT DISTINCT FROM p_new_id_type_cmd THEN RETURN; END IF;
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
$body$;
COMMENT ON PROCEDURE logistique.ps_crud_commande(integer,integer,integer,integer,integer,integer,character varying)
 IS 'Valide les catégories du référentiel et un sens Entrée/Sortie dès la création. Un changement de type applique le delta net par article dans un ordre de verrouillage stable et réaligne les mouvements liés, sans doublon.';
CREATE OR REPLACE FUNCTION logistique.tr_delete_commande() RETURNS trigger LANGUAGE plpgsql AS $body$
BEGIN
 CALL logistique.ps_crud_commande(OLD."ID_Commande",OLD."ID_TypeCmdFk",NULL,NULL,NULL,NULL,'DELETE');
 RETURN OLD;
END;$body$;
COMMENT ON FUNCTION logistique.tr_delete_commande() IS 'Compatibilité de la fonction historique non raccordée : utilise la signature courante à sept paramètres. La cascade des lignes assure les effets stock.';

CREATE OR REPLACE FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $body$
 SELECT p_data - ARRAY['MotdepasseUser','password','Password','MotDePasse','accessToken','refreshToken'];
$body$;
COMMENT ON FUNCTION systeme.fn_audit_sans_secrets(jsonb) IS 'Retire les champs de mot de passe et jetons d’une image de ligne JSON d’audit ; conserve NULL et les autres données de traçabilité.';
CREATE OR REPLACE FUNCTION systeme.audit_log_function() RETURNS trigger LANGUAGE plpgsql AS $body$
DECLARE before_row jsonb; after_row jsonb; entity_id integer;
BEGIN
 IF TG_OP IN ('DELETE','UPDATE') THEN before_row:=systeme.fn_audit_sans_secrets(to_jsonb(OLD)); END IF;
 IF TG_OP IN ('INSERT','UPDATE') THEN after_row:=systeme.fn_audit_sans_secrets(to_jsonb(NEW)); END IF;
 entity_id:=coalesce((after_row->>'IdEntiteFk')::integer,(before_row->>'IdEntiteFk')::integer);
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk")
 VALUES(TG_TABLE_NAME,TG_OP,before_row,after_row,current_timestamp,entity_id);
 RETURN NULL;
END;$body$;
COMMENT ON FUNCTION systeme.audit_log_function() IS 'Audit AFTER INSERT/UPDATE/DELETE transactionnel : lit le contexte par JSON sans supposer une colonne IdEntiteFk, ne recopie ni mots de passe ni jetons et accepte une entité absente.';
CREATE OR REPLACE VIEW systeme."V_Audit_log" AS
 SELECT a."IdLog",a."TableName",a."Operation",a."ChangedAt",e."NomEntite",
 systeme.fn_audit_sans_secrets(a."OldData") AS "OldData",
 systeme.fn_audit_sans_secrets(a."NewData") AS "NewData"
 FROM systeme."T_Audit_Log" a LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk";
COMMENT ON VIEW systeme."V_Audit_log" IS 'Journal au grain événement. Les images avant/après masquent les champs de mot de passe et jetons, y compris pour les événements historiques. Les droits restent imposés par le service.';
COMMENT ON COLUMN systeme."V_Audit_log"."OldData" IS 'Image avant opération sans champs de mot de passe ni jetons ; NULL pour une insertion.';
COMMENT ON COLUMN systeme."V_Audit_log"."NewData" IS 'Image après opération sans champs de mot de passe ni jetons ; NULL pour une suppression.';

DO $body$
DECLARE next_id bigint; seq text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='systeme' AND table_name='T_Licence' AND column_name='IdLicence' AND is_identity='YES') THEN
  ALTER TABLE systeme."T_Licence" ALTER COLUMN "IdLicence" ADD GENERATED BY DEFAULT AS IDENTITY;
  SELECT coalesce(max("IdLicence"),0)::bigint+1 INTO next_id FROM systeme."T_Licence";
  seq:=pg_get_serial_sequence('systeme."T_Licence"','IdLicence');
  EXECUTE format('ALTER SEQUENCE %s RESTART WITH %s',seq,next_id);
 END IF;
END;$body$;
COMMENT ON COLUMN systeme."T_Licence"."IdLicence" IS 'Identifiant automatiquement attribué par une identité PostgreSQL ; les identifiants antérieurs sont conservés.';
CREATE OR REPLACE FUNCTION systeme.prevent_multiple_active_licenses() RETURNS trigger LANGUAGE plpgsql AS $body$
BEGIN
 -- Sérialise aussi les activations et changements d’entité ; pas seulement INSERT.
 PERFORM 1 FROM systeme."T_Entite" e
 WHERE e."IdEntite"=ANY(ARRAY[NEW."IdEntiteFk",CASE WHEN TG_OP='UPDATE' THEN OLD."IdEntiteFk" ELSE NULL END])
 ORDER BY e."IdEntite" FOR NO KEY UPDATE;
 IF NEW."ValideLicence" IS TRUE AND EXISTS(
  SELECT 1 FROM systeme."T_Licence" l WHERE l."IdEntiteFk"=NEW."IdEntiteFk"
  AND l."IdLicence" IS DISTINCT FROM NEW."IdLicence" AND l."ValideLicence" IS TRUE
  AND l."DateDebut"<NEW."DateFin" AND NEW."DateDebut"<l."DateFin"
 ) THEN RAISE EXCEPTION 'Deux licences valides ne peuvent pas couvrir la même période pour une entité.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;$body$;
DROP TRIGGER IF EXISTS trigger_prevent_multiple_licenses ON systeme."T_Licence";
CREATE TRIGGER trigger_prevent_multiple_licenses BEFORE INSERT OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.prevent_multiple_active_licenses();
COMMENT ON FUNCTION systeme.prevent_multiple_active_licenses() IS 'Verrouille les entités dans un ordre stable et refuse tout chevauchement de périodes de licences déclarées valides, à l’insertion et à la mise à jour, y compris concurrentes. Les renouvellements sans chevauchement et licences désactivées restent autorisés.';
COMMENT ON TRIGGER trigger_prevent_multiple_licenses ON systeme."T_Licence" IS 'Contrôle des périodes concurrentes de licences valides après verrouillage de leur entité.';
CREATE OR REPLACE FUNCTION systeme.update_licence_status() RETURNS trigger LANGUAGE plpgsql AS $body$
BEGIN NEW."ExpireeLicence":=NEW."DateFin"<=current_timestamp; RETURN NEW; END;$body$;
COMMENT ON FUNCTION systeme.update_licence_status() IS 'Calcule le drapeau d’expiration au moment de l’écriture. La vue calcule l’état courant à la lecture pour tenir compte du passage du temps.';
CREATE OR REPLACE VIEW systeme."V_Licence_active" AS
 SELECT l."IdLicence",l."IdEntiteFk",e."NomEntite",l."DateDebut",l."DateFin",l."ValideLicence",
 (l."DateFin"<=current_timestamp) AS "ExpireeLicence",
 CASE WHEN l."ValideLicence" IS NOT TRUE THEN 'Inactive'
 WHEN l."DateFin"<=current_timestamp THEN 'Expirée'
 WHEN l."DateDebut">current_timestamp THEN 'À venir' ELSE 'Active' END::text AS statut_licence
 FROM systeme."T_Licence" l LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=l."IdEntiteFk";
COMMENT ON VIEW systeme."V_Licence_active" IS 'Suivi de toutes les licences au grain licence ; état temporel calculé à chaque lecture : Inactive, Expirée, À venir ou Active. Le nom historique est conservé ; aucune licence historique n’est masquée.';
COMMENT ON COLUMN systeme."V_Licence_active"."ExpireeLicence" IS 'Vrai dès que DateFin est atteinte à l’instant de lecture, indépendamment du drapeau stocké.';
COMMENT ON COLUMN systeme."V_Licence_active".statut_licence IS 'Inactive si désactivée ; sinon Expirée à DateFin, À venir avant DateDebut, Active durant la période de validité.';
CREATE OR REPLACE FUNCTION systeme.notify_licence_expiry() RETURNS trigger LANGUAGE plpgsql AS $body$
DECLARE recipient integer; notification_type integer;
BEGIN
 IF NEW."ValideLicence" IS NOT TRUE OR NEW."DateFin"::date-current_date<>7 THEN RETURN NEW; END IF;
 IF TG_OP='UPDATE' AND NEW."DateFin" IS NOT DISTINCT FROM OLD."DateFin" AND NEW."ValideLicence" IS NOT DISTINCT FROM OLD."ValideLicence" THEN RETURN NEW; END IF;
 SELECT u."IdUser" INTO recipient FROM systeme."T_Utilisateurs" u LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique"=u."IdRoleFk"
 WHERE u."IdEntiteFk"=NEW."IdEntiteFk" AND u."ValideUser" IS TRUE
 AND (u."Is_Admin" OR u."Is_staff" OR r."NomGenerique"='Admin Entité')
 ORDER BY u."Is_Admin" DESC,u."Is_staff" DESC,u."IdUser" LIMIT 1;
 SELECT "ID_Generique" INTO notification_type FROM referentiel."T_Generique" WHERE "NomGenerique"='Notification' AND "ValideGenerique" IS TRUE ORDER BY "ID_Generique" LIMIT 1;
 IF recipient IS NOT NULL AND notification_type IS NOT NULL THEN
  INSERT INTO communication."T_Communication"("IdUserFk","IdTypeCommunication","ContenuCommunication","DateCommunication","ValideCommunication","LectureCommunication","IdEntiteFk")
  VALUES(recipient,notification_type,'Votre licence expirera dans 7 jours. Veuillez la renouveler.',current_timestamp,true,false,NEW."IdEntiteFk");
 END IF;
 RETURN NEW;
END;$body$;
COMMENT ON FUNCTION systeme.notify_licence_expiry() IS 'À l’écriture d’une licence valide arrivant à J+7 calendaires, notifie un gestionnaire actif de la même entité. Une modification sans changement de date ni activation ne répète pas la notification. Ce trigger ne constitue pas une tâche quotidienne planifiée.';

CREATE OR REPLACE FUNCTION referentiel.fn_guard_sens_stock() RETURNS trigger LANGUAGE plpgsql AS $body$
DECLARE old_sign integer; new_sign integer;
BEGIN
 IF OLD."ID_CategorieGeneriqueFk"=64 AND (
 EXISTS(SELECT 1 FROM logistique."T_Commande" WHERE "ID_TypeCmdFk"=OLD."ID_Generique") OR
 EXISTS(SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_TypeMvtFk"=OLD."ID_Generique")) THEN
  old_sign:=CASE WHEN OLD."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN OLD."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END;
  new_sign:=CASE WHEN NEW."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN NEW."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF NEW."ID_CategorieGeneriqueFk"<>64 OR new_sign<>old_sign THEN
   RAISE EXCEPTION 'Le sens d’un type de stock déjà utilisé ne peut pas être changé.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;$body$;
DROP TRIGGER IF EXISTS tr_guard_sens_stock ON referentiel."T_Generique";
CREATE TRIGGER tr_guard_sens_stock BEFORE UPDATE ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION referentiel.fn_guard_sens_stock();
COMMENT ON FUNCTION referentiel.fn_guard_sens_stock() IS 'Protège le signe Entrée/Sortie et la catégorie 64 d’un type déjà utilisé par une commande ou un mouvement ; évite une réinterprétation rétroactive du stock. Un changement de libellé conservant le signe reste permis.';
COMMENT ON TRIGGER tr_guard_sens_stock ON referentiel."T_Generique" IS 'Empêche qu’une modification du référentiel inverse ou efface le sens d’un historique de stock existant.';

CREATE OR REPLACE FUNCTION communication.fn_lock_discussion_message() RETURNS trigger LANGUAGE plpgsql AS $body$
DECLARE ids integer[];
BEGIN
 IF TG_OP='INSERT' THEN ids:=ARRAY[NEW."IdDiscussionFk"];
 ELSIF TG_OP='DELETE' THEN ids:=ARRAY[OLD."IdDiscussionFk"];
 ELSE ids:=ARRAY[OLD."IdDiscussionFk",NEW."IdDiscussionFk"]; END IF;
 PERFORM 1 FROM communication."T_Discussion" WHERE "IdDiscussion"=ANY(ids) ORDER BY "IdDiscussion" FOR NO KEY UPDATE;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END;$body$;
CREATE OR REPLACE FUNCTION communication.fn_sync_dernier_message() RETURNS trigger LANGUAGE plpgsql AS $body$
DECLARE ids integer[];
BEGIN
 IF TG_OP='INSERT' THEN ids:=ARRAY[NEW."IdDiscussionFk"];
 ELSIF TG_OP='DELETE' THEN ids:=ARRAY[OLD."IdDiscussionFk"];
 ELSE ids:=ARRAY[OLD."IdDiscussionFk",NEW."IdDiscussionFk"]; END IF;
 UPDATE communication."T_Discussion" d SET "DernierMessageAt"=(SELECT max(c."DateChat") FROM communication."T_Chat" c WHERE c."IdDiscussionFk"=d."IdDiscussion")
 WHERE d."IdDiscussion"=ANY(ids);
 RETURN NULL;
END;$body$;
DROP TRIGGER IF EXISTS tr_00_lock_discussion_message ON communication."T_Chat";
CREATE TRIGGER tr_00_lock_discussion_message BEFORE INSERT OR UPDATE OR DELETE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_lock_discussion_message();
DROP TRIGGER IF EXISTS tr_sync_dernier_message ON communication."T_Chat";
CREATE TRIGGER tr_sync_dernier_message AFTER INSERT OR UPDATE OR DELETE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_sync_dernier_message();
COMMENT ON FUNCTION communication.fn_lock_discussion_message() IS 'Verrouille les discussions parentes dans l’ordre des identifiants avant une mutation de message, afin de sérialiser le calcul de la dernière activité.';
COMMENT ON FUNCTION communication.fn_sync_dernier_message() IS 'Maintient DernierMessageAt égal au maximum des DateChat après insertion, modification, déplacement ou suppression ; NULL quand la discussion n’a plus de message. Le parent est verrouillé par le trigger BEFORE associé.';
COMMENT ON TRIGGER tr_00_lock_discussion_message ON communication."T_Chat" IS 'Verrou des discussions avant modification de leurs messages.';
COMMENT ON TRIGGER tr_sync_dernier_message ON communication."T_Chat" IS 'Synchronise la dernière activité avec les messages effectivement présents.';

CREATE TABLE IF NOT EXISTS analytics."T_Recherche" (
 "IdRecherche" integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
 "IdUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL,
 "TexteRecherche" text NOT NULL CHECK(length(btrim("TexteRecherche")) BETWEEN 1 AND 1000),
 "TypeRecherche" varchar(80),
 "ID_ArticleResultFk" integer REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE ON DELETE SET NULL,
 "IdEntiteResultFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL,
 "IdSpecialiteFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL,
 "LatitudeUser" numeric(9,6) CHECK("LatitudeUser" BETWEEN -90 AND 90),
 "LongitudeUser" numeric(9,6) CHECK("LongitudeUser" BETWEEN -180 AND 180),
 "DateRecherche" timestamptz NOT NULL DEFAULT current_timestamp
);
COMMENT ON TABLE analytics."T_Recherche" IS 'Événements de recherche explicitement enregistrés par un service autorisé. Aucun suivi automatique ni historique fictif n’est activé par la création de ce socle. Accès administratif global ; appliquer une politique de conservation avant une collecte réelle.';
COMMENT ON COLUMN analytics."T_Recherche"."IdRecherche" IS 'Identifiant automatique de l’événement de recherche.';
COMMENT ON COLUMN analytics."T_Recherche"."IdUserFk" IS 'Utilisateur ayant initié la recherche si connu ; NULL après suppression de son compte.';
COMMENT ON COLUMN analytics."T_Recherche"."TexteRecherche" IS 'Texte recherché non vide, limité à 1000 caractères ; peut contenir des données privées, donc accès restreint.';
COMMENT ON COLUMN analytics."T_Recherche"."TypeRecherche" IS 'Qualification textuelle facultative du contexte de recherche ; ne remplace pas un résultat effectivement lié.';
COMMENT ON COLUMN analytics."T_Recherche"."ID_ArticleResultFk" IS 'Article résultat de la recherche s’il existe ; NULL après suppression de cet article.';
COMMENT ON COLUMN analytics."T_Recherche"."IdEntiteResultFk" IS 'Structure résultat de la recherche ; ne constitue pas l’organisation propriétaire de l’événement.';
COMMENT ON COLUMN analytics."T_Recherche"."IdSpecialiteFk" IS 'Spécialité recherchée dans le référentiel si renseignée.';
COMMENT ON COLUMN analytics."T_Recherche"."LatitudeUser" IS 'Latitude facultative en degrés décimaux, de -90 à 90 ; aucune collecte automatique n’est activée.';
COMMENT ON COLUMN analytics."T_Recherche"."LongitudeUser" IS 'Longitude facultative en degrés décimaux, de -180 à 180 ; aucune collecte automatique n’est activée.';
COMMENT ON COLUMN analytics."T_Recherche"."DateRecherche" IS 'Horodatage avec fuseau de l’événement, attribué par PostgreSQL si absent.';
CREATE INDEX IF NOT EXISTS idx_recherche_article_date ON analytics."T_Recherche"("ID_ArticleResultFk","DateRecherche");
CREATE INDEX IF NOT EXISTS idx_recherche_user ON analytics."T_Recherche"("IdUserFk");
CREATE OR REPLACE VIEW analytics."V_Recherche" AS
 SELECT a."ID_Article",a."NomArticle",count(r."IdRecherche") AS nbrerecherches
 FROM analytics."T_Recherche" r JOIN logistique."T_Article" a ON a."ID_Article"=r."ID_ArticleResultFk"
 GROUP BY a."ID_Article",a."NomArticle";
COMMENT ON VIEW analytics."V_Recherche" IS 'Nombre d’événements réellement enregistrés par article résultat, au grain article. Les événements sans article et les articles sans recherche ne produisent pas de ligne ; aucun total fictif.';
COMMENT ON COLUMN analytics."V_Recherche"."ID_Article" IS 'Article résultat, clé du grain de l’agrégat.';
COMMENT ON COLUMN analytics."V_Recherche"."NomArticle" IS 'Nom courant de l’article résultat.';
COMMENT ON COLUMN analytics."V_Recherche".nbrerecherches IS 'Nombre exact de lignes de T_Recherche liées à cet article ; ne représente ni les utilisateurs distincts ni les ventes.';

CREATE OR REPLACE VIEW professionnel."V_Professionnel_Public" AS SELECT p."IdProfessionnel",p."ExperienceAns",p."ValideProfessionnel",
 jsonb_build_object('ID_Generique',s."ID_Generique",'NomGenerique',s."NomGenerique",'AbrGenerique',s."AbrGenerique") AS "T_GeneriqueSpecialite",
 jsonb_build_object('ID_Generique',t."ID_Generique",'NomGenerique',t."NomGenerique",'AbrGenerique',t."AbrGenerique") AS "T_GeneriqueType",
 jsonb_build_object('IdUser',u."IdUser",'NomUser',u."NomUser",'PrenomUser',u."PrenomUser",'UrlPhoto',u."UrlPhoto") AS "T_Utilisateurs",
 COALESCE((SELECT jsonb_agg(jsonb_build_object('EstPrincipal',l."EstPrincipal",'T_Entite',jsonb_build_object('IdEntite',e."IdEntite",'NomEntite',e."NomEntite",'PhoneEntite',e."PhoneEntite",'AdresseEntite',e."AdresseEntite")) ORDER BY l."EstPrincipal" DESC,l."IdEntiteFk") FROM professionnel."T_Professionnel_Entite" l JOIN systeme."T_Entite" e ON e."IdEntite"=l."IdEntiteFk" WHERE l."IdProfessionnelFk"=p."IdProfessionnel" AND e."ValideEntite"=true AND (l."DateDebut" IS NULL OR l."DateDebut"<=current_timestamp) AND (l."DateFin" IS NULL OR l."DateFin">current_timestamp)),'[]'::jsonb) AS "T_Professionnel_Entite"
 FROM professionnel."T_Professionnel" p JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."IdUserFk" LEFT JOIN referentiel."T_Generique" s ON s."ID_Generique"=p."IdSpecialiteFk" LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=p."IdTypeProfessionnelFk" WHERE p."ValideProfessionnel"=true AND u."ValideUser"=true;
COMMENT ON VIEW professionnel."V_Professionnel_Public" IS 'Annuaire public au grain professionnel actif et utilisateur actif. Identité, spécialité et affiliations valables à la date de lecture ; aucun email, téléphone personnel, numéro professionnel ou mot de passe. Les affiliations sont agrégées pour éviter de dupliquer les professionnels.';

CREATE OR REPLACE VIEW systeme."V_Entite_Public" AS SELECT e."IdEntite",e."NomEntite",e."PhoneEntite",e."AdresseEntite",e."ValideEntite",jsonb_build_object('ID_Generique',g."ID_Generique",'NomGenerique',g."NomGenerique",'AbrGenerique',g."AbrGenerique") AS "T_Generique" FROM systeme."T_Entite" e LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=e."IdTypeEntiteFk" WHERE e."ValideEntite"=true;
COMMENT ON VIEW systeme."V_Entite_Public" IS 'Annuaire public des structures actives au grain entité : nom, adresse et téléphone de structure, type ; aucune donnée de connexion utilisateur.';

-- View: professionnel.V_Professionnel_Detail

-- DROP VIEW professionnel."V_Professionnel_Detail";

CREATE OR REPLACE VIEW professionnel."V_Professionnel_Detail"
 AS
 SELECT p."IdProfessionnel",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    p."IdTypeProfessionnelFk",
    tp."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    sp."NomGenerique" AS "Specialite",
    p."NumeroIdentification",
    p."ExperienceAns",
    p."ValideProfessionnel",
    u."PhoneUser",
    u."SexeUser",
    u."UrlPhoto"
   FROM professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON u."IdUser" = p."IdUserFk"
     LEFT JOIN referentiel."T_Generique" tp ON tp."ID_Generique" = p."IdTypeProfessionnelFk"
     LEFT JOIN referentiel."T_Generique" sp ON sp."ID_Generique" = p."IdSpecialiteFk";



-- View: professionnel.V_Professionnel_Global

-- DROP VIEW professionnel."V_Professionnel_Global";

CREATE OR REPLACE VIEW professionnel."V_Professionnel_Global"
 AS
 SELECT p."IdProfessionnel",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    u."PhoneUser",
    p."IdTypeProfessionnelFk",
    type_prof."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    spec."NomGenerique" AS "Specialite",
    p."NumeroIdentification",
    p."ExperienceAns",
    p."ValideProfessionnel",
    p."ObsProfessionnel",
    pe."IdEntiteFk" AS "IdEntite",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    pe."IdTypeLienFk",
    type_lien."NomGenerique" AS "TypeLien",
    pe."EstPrincipal",
    pe."DateDebut",
    pe."DateFin",
    pe."ObsLien",
    el."IdEntiteLocalisation",
    el."Latitude",
    el."Longitude",
    el."IdNiveau_3_Fk",
    el."IdNiveau_4_Fk",
    el."IdNiveau_5_Fk",
    el."AdresseDetaillee"
   FROM professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON u."IdUser" = p."IdUserFk"
     JOIN professionnel."T_Professionnel_Entite" pe ON pe."IdProfessionnelFk" = p."IdProfessionnel"
     JOIN systeme."T_Entite" e ON e."IdEntite" = pe."IdEntiteFk"
     LEFT JOIN systeme."T_Entite_Localisation" el ON el."IdEntiteFk" = e."IdEntite"
     LEFT JOIN referentiel."T_Generique" type_prof ON type_prof."ID_Generique" = p."IdTypeProfessionnelFk"
     LEFT JOIN referentiel."T_Generique" spec ON spec."ID_Generique" = p."IdSpecialiteFk"
     LEFT JOIN referentiel."T_Generique" type_lien ON type_lien."ID_Generique" = pe."IdTypeLienFk";



-- View: professionnel.V_Professionnel_Par_Entite

-- DROP VIEW professionnel."V_Professionnel_Par_Entite";

CREATE OR REPLACE VIEW professionnel."V_Professionnel_Par_Entite"
 AS
 SELECT pe."IdProfessionnelFk",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    p."IdTypeProfessionnelFk",
    tp."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    sp."NomGenerique" AS "Specialite",
    pe."IdEntiteFk",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    e."AdresseEntite",
    e."IdTypeEntiteFk",
    te."NomGenerique" AS "TypeEntite",
    pe."EstPrincipal",
    pe."DateDebut",
    pe."DateFin",
    pe."IdTypeLienFk",
    tl."NomGenerique" AS "TypeLien",
    p."ValideProfessionnel"
   FROM professionnel."T_Professionnel_Entite" pe
     JOIN professionnel."T_Professionnel" p ON p."IdProfessionnel" = pe."IdProfessionnelFk"
     JOIN systeme."T_Utilisateurs" u ON u."IdUser" = p."IdUserFk"
     JOIN systeme."T_Entite" e ON e."IdEntite" = pe."IdEntiteFk"
     LEFT JOIN referentiel."T_Generique" tp ON tp."ID_Generique" = p."IdTypeProfessionnelFk"
     LEFT JOIN referentiel."T_Generique" sp ON sp."ID_Generique" = p."IdSpecialiteFk"
     LEFT JOIN referentiel."T_Generique" te ON te."ID_Generique" = e."IdTypeEntiteFk"
     LEFT JOIN referentiel."T_Generique" tl ON tl."ID_Generique" = pe."IdTypeLienFk";




COMMENT ON VIEW professionnel."V_Professionnel_Detail" IS 'Annuaire administratif au grain professionnel, avec coordonnées personnelles : réservé aux permissions administratives explicites.';
COMMENT ON VIEW professionnel."V_Professionnel_Global" IS 'Détail administratif au grain professionnel × affiliation × localisation ; plusieurs lignes peuvent correspondre à un professionnel. Ne pas sommer ce registre comme un effectif de professionnels.';
COMMENT ON VIEW professionnel."V_Professionnel_Par_Entite" IS 'Affiliations administratives au grain professionnel/entité ; les dates restent visibles, y compris pour les liens historiques.';

-- View: communication.V_Chat

-- DROP VIEW communication."V_Chat";

CREATE OR REPLACE VIEW communication."V_Chat"
 AS
 SELECT c."IdChat",
    c."TextChat",
    c."ChatFile",
    c."ChatLink",
    c."AuthorIdFk" AS "IdUser",
    c."IdDiscussionFk", c."DateChat", c."LuChat",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    e."IdEntite",
    e."NomEntite"
   FROM communication."T_Chat" c
     LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = c."AuthorIdFk"
     LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk";



-- View: communication.V_Communication

-- DROP VIEW communication."V_Communication";

CREATE OR REPLACE VIEW communication."V_Communication"
 AS
 SELECT com."IdCommunication",
    com."DateCommunication",
    com."ContenuCommunication",
    com."ObsCommunication",
    com."ValideCommunication",
    com."LectureCommunication",
    com."IdUserFk" AS "IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    com."IdEntiteFk" AS "IdEntite",
    e."NomEntite",
    com."IdTypeCommunication",
    tg."AbrGenerique" AS "TypeCommunicationAbr",
    tg."NomGenerique" AS "TypeCommunicationLibelle"
   FROM communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = com."IdUserFk"
     LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = com."IdEntiteFk"
     LEFT JOIN referentiel."T_Generique" tg ON tg."ID_Generique" = com."IdTypeCommunication";



-- View: communication.V_Communication_non_lues

-- DROP VIEW communication."V_Communication_non_lues";

CREATE OR REPLACE VIEW communication."V_Communication_non_lues"
 AS
 SELECT com."IdCommunication",
    com."DateCommunication",
    com."ContenuCommunication",
    com."ObsCommunication",
    com."ValideCommunication",
    com."LectureCommunication",
    com."IdUserFk" AS "IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    com."IdEntiteFk" AS "IdEntite",
    e."NomEntite",
    com."IdTypeCommunication",
    tg."AbrGenerique" AS "TypeCommunicationAbr",
    tg."NomGenerique" AS "TypeCommunicationLibelle"
   FROM communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = com."IdUserFk"
     LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = com."IdEntiteFk"
     LEFT JOIN referentiel."T_Generique" tg ON tg."ID_Generique" = com."IdTypeCommunication"
  WHERE com."LectureCommunication" = false AND com."ValideCommunication" = true;




COMMENT ON VIEW communication."V_Chat" IS 'Messages au grain message avec discussion et auteur. Vue privée ; le backend doit contrôler les participants avant toute lecture.';
COMMENT ON VIEW communication."V_Communication" IS 'Notifications au grain communication avec destinataire et entité ; aucune ouverture publique.';
COMMENT ON VIEW communication."V_Communication_non_lues" IS 'Notifications actives et non lues, même grain que V_Communication ; filtrage du destinataire requis.';

-- Validation des clés étrangères existantes, après contrôle sans orphelin.
ALTER TABLE "geolocalisation"."T_Niveau_2" VALIDATE CONSTRAINT "Fk_ID_TypeNiveau_2";
COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_2" ON "geolocalisation"."T_Niveau_2" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "geolocalisation"."T_Niveau_3" VALIDATE CONSTRAINT "Fk_ID_TypeNiveau_2";
COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_2" ON "geolocalisation"."T_Niveau_3" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE';
ALTER TABLE "geolocalisation"."T_Niveau_4" VALIDATE CONSTRAINT "Fk_ID_TypeNiveau_4";
COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_4" ON "geolocalisation"."T_Niveau_4" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_4_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE';
ALTER TABLE "logistique"."T_Article" VALIDATE CONSTRAINT "Fk_ID_CategorieArticle";
COMMENT ON CONSTRAINT "Fk_ID_CategorieArticle" ON "logistique"."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_CategorieArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "logistique"."T_Article" VALIDATE CONSTRAINT "Fk_ID_TypeArticle";
COMMENT ON CONSTRAINT "Fk_ID_TypeArticle" ON "logistique"."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "logistique"."T_Article" VALIDATE CONSTRAINT "Fk_ID_Unite";
COMMENT ON CONSTRAINT "Fk_ID_Unite" ON "logistique"."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UniteFk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "logistique"."T_Article" VALIDATE CONSTRAINT "Fk_ID_User";
COMMENT ON CONSTRAINT "Fk_ID_User" ON "logistique"."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UserFK") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE';
ALTER TABLE "logistique"."T_Commande" VALIDATE CONSTRAINT "Fk_ID_ConditionPaiement";
COMMENT ON CONSTRAINT "Fk_ID_ConditionPaiement" ON "logistique"."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ConditionPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "logistique"."T_Commande" VALIDATE CONSTRAINT "Fk_ID_ModePaiement";
COMMENT ON CONSTRAINT "Fk_ID_ModePaiement" ON "logistique"."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "logistique"."T_Commande" VALIDATE CONSTRAINT "Fk_ID_StatutCmd";
COMMENT ON CONSTRAINT "Fk_ID_StatutCmd" ON "logistique"."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_StatutCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "logistique"."T_Commande" VALIDATE CONSTRAINT "Fk_ID_TypeCmd";
COMMENT ON CONSTRAINT "Fk_ID_TypeCmd" ON "logistique"."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "logistique"."T_Commande" VALIDATE CONSTRAINT "Fk_ID_User";
COMMENT ON CONSTRAINT "Fk_ID_User" ON "logistique"."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE';
ALTER TABLE "logistique"."T_CommandeDetail" VALIDATE CONSTRAINT "Fk_ID_Article";
COMMENT ON CONSTRAINT "Fk_ID_Article" ON "logistique"."T_CommandeDetail" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE';
ALTER TABLE "logistique"."T_Mouvement" VALIDATE CONSTRAINT "Fk_ID_TypeMvt";
COMMENT ON CONSTRAINT "Fk_ID_TypeMvt" ON "logistique"."T_Mouvement" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeMvtFk") REFERENCES referentiel."T_Generique"("ID_Generique")';
ALTER TABLE "logistique"."T_Reglements" VALIDATE CONSTRAINT "Fk_CodeFacture";
COMMENT ON CONSTRAINT "Fk_CodeFacture" ON "logistique"."T_Reglements" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("CodeFactureFk") REFERENCES logistique."T_Commande"("CodeFacture")';
DO $body$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='logistique."T_Article"'::regclass AND conname='ck_article_prix_positifs') THEN ALTER TABLE "logistique"."T_Article" ADD CONSTRAINT "ck_article_prix_positifs" CHECK(("PUArticle" IS NULL OR "PUArticle">=0) AND ("PVArticle" IS NULL OR "PVArticle">=0)) NOT VALID; END IF; END;$body$;
ALTER TABLE "logistique"."T_Article" VALIDATE CONSTRAINT "ck_article_prix_positifs";
DO $body$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='logistique."T_CommandeDetail"'::regclass AND conname='ck_ligne_prix_positif') THEN ALTER TABLE "logistique"."T_CommandeDetail" ADD CONSTRAINT "ck_ligne_prix_positif" CHECK("PUCmdDetail" IS NULL OR "PUCmdDetail">=0) NOT VALID; END IF; END;$body$;
ALTER TABLE "logistique"."T_CommandeDetail" VALIDATE CONSTRAINT "ck_ligne_prix_positif";
DO $body$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='communication."T_Chat"'::regclass AND conname='ck_chat_contenu_non_vide') THEN ALTER TABLE "communication"."T_Chat" ADD CONSTRAINT "ck_chat_contenu_non_vide" CHECK(nullif(btrim("TextChat"),'') IS NOT NULL OR nullif(btrim("ChatFile"),'') IS NOT NULL OR nullif(btrim("ChatLink"),'') IS NOT NULL) NOT VALID; END IF; END;$body$;
ALTER TABLE "communication"."T_Chat" VALIDATE CONSTRAINT "ck_chat_contenu_non_vide";
CREATE UNIQUE INDEX IF NOT EXISTS uq_mouvement_ligne_commande ON logistique."T_Mouvement"("ID_cmdFk","ID_ArticleFk") WHERE "ID_cmdFk" IS NOT NULL;
COMMENT ON INDEX logistique.uq_mouvement_ligne_commande IS 'Un seul mouvement source par paire commande/article ; les ajustements d’article sans commande restent multiples.';
COMMENT ON COLUMN "professionnel"."V_Professionnel_Public"."IdProfessionnel" IS 'Clé du professionnel public actif, une ligne par professionnel.';
COMMENT ON COLUMN "professionnel"."V_Professionnel_Public"."ExperienceAns" IS 'Expérience en années déclarée par le professionnel.';
COMMENT ON COLUMN "professionnel"."V_Professionnel_Public"."ValideProfessionnel" IS 'Vrai pour chaque professionnel de cette projection publique filtrée.';
COMMENT ON COLUMN "professionnel"."V_Professionnel_Public"."T_GeneriqueSpecialite" IS 'Spécialité publique sous forme JSON : identifiant, nom et abréviation du référentiel.';
COMMENT ON COLUMN "professionnel"."V_Professionnel_Public"."T_GeneriqueType" IS 'Type professionnel public sous forme JSON : identifiant, nom et abréviation.';
COMMENT ON COLUMN "professionnel"."V_Professionnel_Public"."T_Utilisateurs" IS 'Identité publique JSON limitée à IdUser, NomUser, PrenomUser et UrlPhoto ; sans email, téléphone personnel ni mot de passe.';
COMMENT ON COLUMN "professionnel"."V_Professionnel_Public"."T_Professionnel_Entite" IS 'Affiliations vers les structures actives, valables à la date de lecture ; tri principal puis identifiant, tableau JSON vide si aucune.';
COMMENT ON COLUMN "systeme"."V_Entite_Public"."T_Generique" IS 'Type de structure sous forme JSON : identifiant, nom et abréviation du référentiel.';

-- Compléter les commentaires des objets nouveaux à partir des définitions vérifiées.
DO $body$
DECLARE r record; inherited text;
BEGIN
 FOR r IN SELECT n.nspname s,c.relname t,a.attname col,a.attnum,c.oid
 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('professionnel','communication','systeme') AND c.relkind='v'
 AND a.attnum>0 AND NOT a.attisdropped AND col_description(c.oid,a.attnum) IS NULL
 LOOP
  SELECT col_description(src.oid,a.attnum) INTO inherited
  FROM pg_attribute a JOIN pg_class src ON src.oid=a.attrelid JOIN pg_namespace sn ON sn.oid=src.relnamespace
  WHERE src.relkind='r' AND a.attname=r.col AND a.attnum>0 AND NOT a.attisdropped
  AND sn.nspname IN ('systeme','professionnel','communication','referentiel')
  AND col_description(src.oid,a.attnum) IS NOT NULL ORDER BY (sn.nspname=r.s) DESC,src.oid LIMIT 1;
  EXECUTE format('COMMENT ON COLUMN %I.%I.%I IS %L',r.s,r.t,r.col,
   coalesce(inherited,'Projection SQL de '||r.col||' ; lire le commentaire de la vue pour son grain et son périmètre.'));
 END LOOP;
 FOR r IN SELECT n.nspname s,c.relname t,co.conname name,pg_get_constraintdef(co.oid,true) def
 FROM pg_constraint co JOIN pg_class c ON c.oid=co.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('analytics','communication','logistique') AND obj_description(co.oid,'pg_constraint') IS NULL
 LOOP EXECUTE format('COMMENT ON CONSTRAINT %I ON %I.%I IS %L',r.name,r.s,r.t,'Intégrité imposée par PostgreSQL : '||r.def); END LOOP;
 FOR r IN SELECT n.nspname s,c.relname name,c.relkind kind,c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('analytics','systeme') AND c.relkind IN ('i','S') AND obj_description(c.oid,'pg_class') IS NULL
 LOOP
  EXECUTE format('COMMENT ON %s %I.%I IS %L',CASE WHEN r.kind='i' THEN 'INDEX' ELSE 'SEQUENCE' END,r.s,r.name,
   CASE WHEN r.kind='i' THEN 'Index de contrainte ou accès : '||pg_get_indexdef(r.oid) ELSE 'Séquence technique d’identité attribuant les identifiants sans réécrire les lignes existantes.' END);
 END LOOP;
END;$body$;

CREATE OR REPLACE VIEW geolocalisation."V_Pop_N3_Couverte_Sites" AS
 WITH sites AS (
  SELECT n5.*,coalesce(n5."ID_Niveau_3_Fk",n4."ID_Niveau_3_Fk") region
  FROM geolocalisation."T_Niveau_5" n5 LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n4."ID_Niveau_4"=n5."ID_Niveau_4_Fk"
 )
 SELECT n0."ID_Niveau_0",n0."NomNiveau_0",n1."ID_Niveau_1",n1."NomNiveau_1",n2."ID_Niveau_2",n2."NomNiveau_2",n3."ID_Niveau_3",n3."NomNiveau_3",
 s."ID_TypeNiveau_5_Fk",coalesce(g."AbrGenerique",' '::varchar) AS "Type_Niveau_5",sum(coalesce(s."PopulationNiveau_5",0::numeric)) AS "Pop_Cum_Sites"
 FROM geolocalisation."T_Niveau_3" n3
 LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK"
 LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n1."ID_Niveau_1"=n2."ID_Niveau_1_FK"
 LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n0."ID_Niveau_0"=n1."ID_Niveau_0_Fk"
 LEFT JOIN sites s ON s.region=n3."ID_Niveau_3"
 LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=s."ID_TypeNiveau_5_Fk"
 GROUP BY n0."ID_Niveau_0",n0."NomNiveau_0",n1."ID_Niveau_1",n1."NomNiveau_1",n2."ID_Niveau_2",n2."NomNiveau_2",n3."ID_Niveau_3",n3."NomNiveau_3",s."ID_TypeNiveau_5_Fk",g."AbrGenerique";
COMMENT ON VIEW geolocalisation."V_Pop_N3_Couverte_Sites" IS 'Population déclarée des sites par niveau 3 et type de site. Inclut le rattachement direct au niveau 3 et le repli par le niveau 4, comme V_Niveau_5 ; chaque site contribue une seule fois. Les populations absentes restent coalescées à zéro selon le contrat historique ; ce total ne prouve pas une couverture démographique sans chevauchement.';
CREATE OR REPLACE VIEW geolocalisation."V_Stats_N3_Structures" AS
 WITH structures AS (
  SELECT coalesce(n5."ID_Niveau_3_Fk",n4."ID_Niveau_3_Fk") region,n4."ID_Niveau_4",n4."ID_TypeNiveau_4_Fk",n5."ID_Niveau_5",n5."ID_TypeNiveau_5_Fk"
  FROM geolocalisation."T_Niveau_4" n4 LEFT JOIN geolocalisation."T_Niveau_5" n5 ON n5."ID_Niveau_4_Fk"=n4."ID_Niveau_4"
  UNION ALL
  SELECT n5."ID_Niveau_3_Fk",NULL::integer,NULL::integer,n5."ID_Niveau_5",n5."ID_TypeNiveau_5_Fk"
  FROM geolocalisation."T_Niveau_5" n5 WHERE n5."ID_Niveau_4_Fk" IS NULL AND n5."ID_Niveau_3_Fk" IS NOT NULL
 )
 SELECT n0."ID_Niveau_0",n0."NomNiveau_0",n1."ID_Niveau_1",n1."NomNiveau_1",n2."ID_Niveau_2",n2."NomNiveau_2",n3."ID_Niveau_3",n3."NomNiveau_3",
 s."ID_TypeNiveau_4_Fk",coalesce(g4."AbrGenerique",' '::varchar) AS "Type_Niveau_4",
 s."ID_TypeNiveau_5_Fk",coalesce(g5."AbrGenerique",' '::varchar) AS "Type_Niveau_5",
 count(DISTINCT s."ID_Niveau_4") AS "Nb_Aires_Sante",count(DISTINCT s."ID_Niveau_5") AS "Nb_Structures_Sante"
 FROM geolocalisation."T_Niveau_3" n3
 LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK"
 LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n1."ID_Niveau_1"=n2."ID_Niveau_1_FK"
 LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n0."ID_Niveau_0"=n1."ID_Niveau_0_Fk"
 LEFT JOIN structures s ON s.region=n3."ID_Niveau_3"
 LEFT JOIN referentiel."T_Generique" g4 ON g4."ID_Generique"=s."ID_TypeNiveau_4_Fk"
 LEFT JOIN referentiel."T_Generique" g5 ON g5."ID_Generique"=s."ID_TypeNiveau_5_Fk"
 GROUP BY n0."ID_Niveau_0",n0."NomNiveau_0",n1."ID_Niveau_1",n1."NomNiveau_1",n2."ID_Niveau_2",n2."NomNiveau_2",n3."ID_Niveau_3",n3."NomNiveau_3",s."ID_TypeNiveau_4_Fk",g4."AbrGenerique",s."ID_TypeNiveau_5_Fk",g5."AbrGenerique";
COMMENT ON VIEW geolocalisation."V_Stats_N3_Structures" IS 'Effectifs distincts par niveau 3 et paire de types niveau 4/niveau 5. Inclut les sites directement rattachés au niveau 3, sans leur inventer une aire de santé. Le nombre d’aires n’est pas additif entre groupes de types de sites.';
COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Nb_Structures_Sante" IS 'Nombre de sites distincts du groupe, par rattachement direct au niveau 3 ou via une aire ; aucun site direct n’est omis.';
COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."Pop_Cum_Sites" IS 'Somme des populations déclarées des sites du groupe, avec rattachement direct au niveau 3 ou via le niveau 4 ; absence coalescée à zéro selon le contrat existant.';

COMMIT;
