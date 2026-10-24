-- Structure canonique SauverNdeko vérifiée le 24/10/2026 ; AUCUNE donnée.
-- Installation sur base vide uniquement, avec psql -X -v ON_ERROR_STOP=1 -f.
-- Une base existante reçoit uniquement les migrations versionnées, pas ce fichier.
-- Schémas métier uniquement ; les tables natives public sont créées par manage.py migrate.
--
-- PostgreSQL database dump
--

\restrict e4nuZPOf6YNStl1uWqfrqr3hpJkqpGLB7dlGCtSNVWHRrAitNe7niriwM9dkPjS

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: analytics; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA analytics;


--
-- Name: SCHEMA analytics; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA analytics IS 'Domaine réservé aux recherches et analyses de la plateforme ; aucun objet applicatif installé lors du relevé du 24/10/2026.';


--
-- Name: communication; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA communication;


--
-- Name: SCHEMA communication; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA communication IS 'Discussions, messages de conversation et communications adressées aux utilisateurs et entités.';


--
-- Name: geolocalisation; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA geolocalisation;


--
-- Name: SCHEMA geolocalisation; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA geolocalisation IS 'Référentiel hiérarchique des territoires, sites, populations et indicateurs de couverture géographique.';


--
-- Name: logistique; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA logistique;


--
-- Name: SCHEMA logistique; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA logistique IS 'Articles, commandes, lignes, stock, mouvements et règlements ; vues et routines de cohérence logistique.';


--
-- Name: operations; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA operations;


--
-- Name: SCHEMA operations; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA operations IS 'Paiements, archives et caisses par entité et devise, avec routines de mouvement, notification et contrôle.';


--
-- Name: professionnel; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA professionnel;


--
-- Name: SCHEMA professionnel; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA professionnel IS 'Profils professionnels, spécialités et rattachements aux entités.';


--
-- Name: referentiel; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA referentiel;


--
-- Name: SCHEMA referentiel; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA referentiel IS 'Catégories et valeurs génériques utilisées pour les nomenclatures, statuts, types, unités et listes de référence.';


--
-- Name: systeme; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA systeme;


--
-- Name: SCHEMA systeme; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA systeme IS 'Comptes, entités, localisations, licences, connexions, audit et paramètres partagés de l’administration.';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: fn_lock_discussion_message(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_lock_discussion_message() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE ids integer[];
BEGIN
 IF TG_OP='INSERT' THEN ids:=ARRAY[NEW."IdDiscussionFk"];
 ELSIF TG_OP='DELETE' THEN ids:=ARRAY[OLD."IdDiscussionFk"];
 ELSE ids:=ARRAY[OLD."IdDiscussionFk",NEW."IdDiscussionFk"]; END IF;
 PERFORM 1 FROM communication."T_Discussion" WHERE "IdDiscussion"=ANY(ids) ORDER BY "IdDiscussion" FOR NO KEY UPDATE;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END;$$;


--
-- Name: FUNCTION fn_lock_discussion_message(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_lock_discussion_message() IS 'Verrouille les discussions parentes dans l’ordre des identifiants avant une mutation de message, afin de sérialiser le calcul de la dernière activité.';


--
-- Name: fn_sync_dernier_message(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_sync_dernier_message() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE ids integer[];
BEGIN
 IF TG_OP='INSERT' THEN ids:=ARRAY[NEW."IdDiscussionFk"];
 ELSIF TG_OP='DELETE' THEN ids:=ARRAY[OLD."IdDiscussionFk"];
 ELSE ids:=ARRAY[OLD."IdDiscussionFk",NEW."IdDiscussionFk"]; END IF;
 UPDATE communication."T_Discussion" d SET "DernierMessageAt"=(SELECT max(c."DateChat") FROM communication."T_Chat" c WHERE c."IdDiscussionFk"=d."IdDiscussion")
 WHERE d."IdDiscussion"=ANY(ids);
 RETURN NULL;
END;$$;


--
-- Name: FUNCTION fn_sync_dernier_message(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_sync_dernier_message() IS 'Maintient DernierMessageAt égal au maximum des DateChat après insertion, modification, déplacement ou suppression ; NULL quand la discussion n’a plus de message. Le parent est verrouillé par le trigger BEFORE associé.';


--
-- Name: fn_assert_generique_category(integer, integer, text, text); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_assert_generique_category(p_id_generique integer, p_id_categorie_generique integer, p_contexte text, p_nom_colonne text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE v_nom_categorie text;
BEGIN IF p_id_generique IS NULL THEN RETURN;
END IF;
SELECT cg."NomCategorieGenerique" INTO v_nom_categorie
FROM referentiel."T_CategorieGenerique" cg
WHERE cg."ID_CategorieGenerique" = p_id_categorie_generique;
IF NOT EXISTS (
    SELECT 1
    FROM referentiel."T_Generique" g
    WHERE g."ID_Generique" = p_id_generique
        AND g."ID_CategorieGeneriqueFk" = p_id_categorie_generique
) THEN IF EXISTS (
    SELECT 1
    FROM referentiel."T_Generique" g
    WHERE g."ID_Generique" = p_id_generique
) THEN RAISE EXCEPTION '% : %= % present dans T_Generique mais hors categorie attendue % (%).',
p_contexte,
p_nom_colonne,
p_id_generique,
p_id_categorie_generique,
COALESCE(v_nom_categorie, 'Categorie inconnue');
END IF;
RAISE EXCEPTION '% : %= % introuvable dans T_Generique pour la categorie % (%).',
p_contexte,
p_nom_colonne,
p_id_generique,
p_id_categorie_generique,
COALESCE(v_nom_categorie, 'Categorie inconnue');
END IF;
END;
$$;


--
-- Name: FUNCTION fn_assert_generique_category(p_id_generique integer, p_id_categorie_generique integer, p_contexte text, p_nom_colonne text); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_assert_generique_category(p_id_generique integer, p_id_categorie_generique integer, p_contexte text, p_nom_colonne text) IS 'Valide qu’un identifiant générique renseigné appartient à la catégorie attendue ; accepte NULL et lève une exception en cas de référence absente ou de mauvaise catégorie. Les paramètres de contexte/colonne servent au diagnostic ; aucune écriture.';


--
-- Name: fn_audit_stock(integer, timestamp without time zone); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_audit_stock(p_id_article integer DEFAULT NULL::integer, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("ID_Article" integer, "CodeArticleInterne" character varying, "NomArticle" character varying, "StockArticle" numeric, "StockMouvements" numeric, "Ecart" numeric, "N_Mouvements" integer, "QteEntree" numeric, "QteSortie" numeric)
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    COALESCE(a."QteArticle", 0)::numeric AS "StockArticle",
    COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS "StockMouvements",
    COALESCE(a."QteArticle", 0)::numeric - COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS "Ecart",
    COUNT(v."ID_Mvt")::integer AS "N_Mouvements",
    COALESCE(
        SUM(
            CASE
                WHEN v."SigneStock" = 1 THEN COALESCE(v."QteMvt", 0)
                ELSE 0
            END
        ),
        0
    )::numeric AS "QteEntree",
    COALESCE(
        SUM(
            CASE
                WHEN v."SigneStock" = -1 THEN COALESCE(v."QteMvt", 0)
                ELSE 0
            END
        ),
        0
    )::numeric AS "QteSortie"
FROM logistique."T_Article" a
    LEFT JOIN logistique."V_MouvementStock" v ON v."ID_ArticleFk" = a."ID_Article"
    AND (
        p_date_max IS NULL
        OR v."DateMvt" <= p_date_max
    )
WHERE p_id_article IS NULL
    OR a."ID_Article" = p_id_article
GROUP BY a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    a."QteArticle"
ORDER BY a."NomArticle",
    a."ID_Article";
$$;


--
-- Name: FUNCTION fn_audit_stock(p_id_article integer, p_date_max timestamp without time zone); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_audit_stock(p_id_article integer, p_date_max timestamp without time zone) IS 'Lecture SQL STABLE de l’audit au grain article, intégrable par le planificateur pour pousser les filtres d’article. Compare le stock courant aux mouvements signés ; p_date_max borne les mouvements sans reconstituer un stock historique.';


--
-- Name: fn_commande_cloturee(text); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_commande_cloturee(p_statut text) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
 SELECT translate(lower(btrim(COALESCE(p_statut, ''))),
   'àâäéèêëîïôöùûüç', 'aaaeeeeiioouuuc') = 'cloturee';
$$;


--
-- Name: FUNCTION fn_commande_cloturee(p_statut text); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_commande_cloturee(p_statut text) IS 'Prédicat commun de clôture : normalise espaces, casse et accents français du statut ; vrai pour Clôturée/cloturee. Sans lecture de données ni effet de bord.';


--
-- Name: ps_crud_article(integer, integer, integer, integer, numeric, numeric, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_crud_article(IN p_id_article integer, IN p_id_type_article integer, IN p_id_categorie_article integer, IN p_id_unite integer, IN p_old_qte numeric, IN p_new_qte numeric, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_op text;
v_new_qte numeric(14, 3);
BEGIN v_op := upper(trim(p_operation));
v_new_qte := COALESCE(p_new_qte, 0)::numeric(14, 3);
IF v_op IN ('INSERT', 'UPDATE') THEN PERFORM logistique.fn_assert_generique_category(
    p_id_type_article,
    46,
    format('ps_crud_article(%s)', v_op),
    'ID_TypeArticleFk'
);
PERFORM logistique.fn_assert_generique_category(
    p_id_categorie_article,
    40,
    format('ps_crud_article(%s)', v_op),
    'ID_CategorieArticleFk'
);
PERFORM logistique.fn_assert_generique_category(
    p_id_unite,
    34,
    format('ps_crud_article(%s)', v_op),
    'ID_UniteFk'
);
END IF;
IF v_op IN ('INSERT', 'UPDATE')
AND v_new_qte < 0 THEN RAISE EXCEPTION 'ps_crud_article(%) : QteArticle negative interdite pour ID_Article=%.',
v_op,
p_id_article;
END IF;
END;
$$;


--
-- Name: PROCEDURE ps_crud_article(IN p_id_article integer, IN p_id_type_article integer, IN p_id_categorie_article integer, IN p_id_unite integer, IN p_old_qte numeric, IN p_new_qte numeric, IN p_operation character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_crud_article(IN p_id_article integer, IN p_id_type_article integer, IN p_id_categorie_article integer, IN p_id_unite integer, IN p_old_qte numeric, IN p_new_qte numeric, IN p_operation character varying) IS 'Contrôle les catégories article 46/type, 40/catégorie et 34/unité et refuse un stock négatif pour INSERT/UPDATE. Ne produit pas elle-même de mouvement ; les triggers article assurent l’historisation.';


--
-- Name: ps_crud_commande(integer, integer, integer, integer, integer, integer, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying)
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
$$;


--
-- Name: PROCEDURE ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying) IS 'Valide les catégories du référentiel et un sens Entrée/Sortie dès la création. Un changement de type applique le delta net par article dans un ordre de verrouillage stable et réaligne les mouvements liés, sans doublon.';


--
-- Name: ps_crud_commandedetail(integer, integer, numeric, numeric, integer, integer, numeric, numeric, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: PROCEDURE ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying) IS 'Applique le delta net de stock par article verrouillé ; INSERT/UPDATE/DELETE maintiennent un mouvement unique par ligne, son prix et sa quantité. Refuse le stock final négatif, les fractions et les prix négatifs. Les totaux sont recalculés par les triggers de fin d’instruction.';


--
-- Name: ps_crud_reglement(integer, integer, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_crud_reglement(IN p_id_reglement integer, IN p_id_mode_reglement integer, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_op text;
BEGIN v_op := upper(trim(p_operation));
IF v_op IN ('INSERT', 'UPDATE') THEN PERFORM logistique.fn_assert_generique_category(
    p_id_mode_reglement,
    36,
    format('ps_crud_reglement(%s)', v_op),
    'ID_ModeReglementFk'
);
END IF;
END;
$$;


--
-- Name: PROCEDURE ps_crud_reglement(IN p_id_reglement integer, IN p_id_mode_reglement integer, IN p_operation character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_crud_reglement(IN p_id_reglement integer, IN p_id_mode_reglement integer, IN p_operation character varying) IS 'Contrôle l’appartenance du mode de règlement à la catégorie 36 pour INSERT/UPDATE ; ne recalcule pas les règlements ni le reste de facture.';


--
-- Name: ps_update_qte_article(integer, numeric, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_update_qte_article(IN p_id_article_fk integer, IN p_qte numeric, IN p_operateur character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_delta numeric;
v_operateur varchar(1);
v_new_stock numeric;
BEGIN IF p_qte IS NULL
OR p_qte <= 0 THEN RAISE EXCEPTION 'ps_update_qte_article : la quantite doit etre strictement positive (recu=%).',
p_qte;
END IF;
v_operateur := trim(p_operateur);
IF v_operateur NOT IN ('+', '-') THEN RAISE EXCEPTION 'ps_update_qte_article : operateur invalide (recu=%). Utiliser seulement + ou -.',
p_operateur;
END IF;
v_delta := CASE
    WHEN v_operateur = '+' THEN p_qte
    ELSE - p_qte
END;
UPDATE logistique."T_Article"
SET "QteArticle" = COALESCE("QteArticle", 0)::numeric + v_delta
WHERE "ID_Article" = p_id_article_fk
RETURNING "QteArticle" INTO v_new_stock;
IF NOT FOUND THEN RAISE EXCEPTION 'ps_update_qte_article : article % introuvable.',
p_id_article_fk;
END IF;
IF v_new_stock < 0 THEN RAISE EXCEPTION 'ps_update_qte_article : la mise a jour ferait passer le stock de l''article % en negatif (stock final=%).',
p_id_article_fk,
v_new_stock;
END IF;
END;
$$;


--
-- Name: PROCEDURE ps_update_qte_article(IN p_id_article_fk integer, IN p_qte numeric, IN p_operateur character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_update_qte_article(IN p_id_article_fk integer, IN p_qte numeric, IN p_operateur character varying) IS 'Ajoute ou retranche une quantité strictement positive au stock de l’article selon l’opérateur + ou -. Refuse l’article absent, l’opérateur invalide et le stock final négatif ; l’écriture participe à la transaction appelante.';


--
-- Name: ps_update_totaux_commande(integer); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_update_totaux_commande(IN p_id_commande integer)
    LANGUAGE plpgsql
    AS $$
DECLARE v_montant numeric(12,2);
BEGIN
 PERFORM 1 FROM logistique."T_Commande"
 WHERE "ID_Commande" = p_id_commande FOR NO KEY UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 SELECT COALESCE(sum(COALESCE(d."QteCmdDetail",0) * COALESCE(d."PUCmdDetail",0)),0)
 INTO v_montant FROM logistique."T_CommandeDetail" d WHERE d."ID_CmdFk" = p_id_commande;
 UPDATE logistique."T_Commande"
 SET "MontantHT" = v_montant, "MontantTTC" = v_montant
 WHERE "ID_Commande" = p_id_commande
   AND ("MontantHT" IS DISTINCT FROM v_montant OR "MontantTTC" IS DISTINCT FROM v_montant);
END;
$$;


--
-- Name: PROCEDURE ps_update_totaux_commande(IN p_id_commande integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_update_totaux_commande(IN p_id_commande integer) IS 'Verrouille une commande puis recalcule la somme quantité × prix des lignes. Écrit cette somme dans HT et TTC uniquement si nécessaire ; aucun calcul de taxe distinct. Parent absent lors d’une cascade : aucune écriture.';


--
-- Name: tr_crud_article_after(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_article_after() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_new_qte numeric(14, 3);
v_old_qte numeric(14, 3);
v_delta numeric(14, 3);
v_type_mvt integer;
v_qte_mvt integer;
v_skip_report_mvt boolean;
BEGIN v_skip_report_mvt := COALESCE(
    current_setting('logistique.skip_article_report_mvt', true),
    'off'
) = 'on';
IF v_skip_report_mvt THEN RETURN NEW;
END IF;
IF TG_OP = 'INSERT' THEN v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(14, 3);
IF v_new_qte = 0 THEN RETURN NEW;
END IF;
IF v_new_qte <> trunc(v_new_qte) THEN RAISE EXCEPTION 'tr_crud_article_after(INSERT) : QteArticle=% ne peut pas etre historisee dans T_Mouvement.QteMvt entier.',
v_new_qte;
END IF;
SELECT g."ID_Generique" INTO v_type_mvt
FROM referentiel."T_Generique" g
WHERE g."AbrGenerique" ILIKE 'entr%'
    AND g."ID_CategorieGeneriqueFk" = 64
ORDER BY g."ID_Generique"
LIMIT 1;
IF v_type_mvt IS NULL THEN RAISE EXCEPTION 'tr_crud_article_after(INSERT) : type de mouvement Entree introuvable.';
END IF;
v_qte_mvt := v_new_qte::integer;
ELSIF TG_OP = 'UPDATE' THEN v_old_qte := COALESCE(OLD."QteArticle", 0)::numeric(14, 3);
v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(14, 3);
v_delta := v_new_qte - v_old_qte;
IF v_delta = 0 THEN RETURN NEW;
END IF;
IF abs(v_delta) <> trunc(abs(v_delta)) THEN RAISE EXCEPTION 'tr_crud_article_after(UPDATE) : delta=% ne peut pas etre historise dans T_Mouvement.QteMvt entier.',
v_delta;
END IF;
IF v_delta > 0 THEN
SELECT g."ID_Generique" INTO v_type_mvt
FROM referentiel."T_Generique" g
WHERE g."AbrGenerique" ILIKE 'entr%'
    AND g."ID_CategorieGeneriqueFk" = 64
ORDER BY g."ID_Generique"
LIMIT 1;
IF v_type_mvt IS NULL THEN RAISE EXCEPTION 'tr_crud_article_after(UPDATE) : type de mouvement Entree introuvable.';
END IF;
v_qte_mvt := v_delta::integer;
ELSE
SELECT g."ID_Generique" INTO v_type_mvt
FROM referentiel."T_Generique" g
WHERE g."AbrGenerique" ILIKE 'sort%'
    AND g."ID_CategorieGeneriqueFk" = 64
ORDER BY g."ID_Generique"
LIMIT 1;
IF v_type_mvt IS NULL THEN RAISE EXCEPTION 'tr_crud_article_after(UPDATE) : type de mouvement Sortie introuvable.';
END IF;
v_qte_mvt := abs(v_delta)::integer;
END IF;
ELSE RETURN NEW;
END IF;
PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);
INSERT INTO logistique."T_Mouvement" (
        "ID_TypeMvtFk",
        "ID_ArticleFk",
        "ID_cmdFk",
        "DateHeureAutoMvt",
        "DateMvt",
        "QteMvt",
        "PUMvt"
    )
VALUES (
        v_type_mvt,
        NEW."ID_Article",
        NULL,
        now()::timestamp without time zone,
        now()::timestamp without time zone,
        v_qte_mvt,
        COALESCE(NEW."PVArticle", 0)
    );
PERFORM set_config(
    'logistique.allow_t_mouvement_write',
    'off',
    true
);
RETURN NEW;
END;
$$;


--
-- Name: FUNCTION tr_crud_article_after(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_article_after() IS 'Après INSERT/UPDATE d’article, historise le stock initial non nul ou le delta direct en mouvement sans commande, valorisé avec PVArticle. Refuse les deltas fractionnaires ; le drapeau transactionnel skip_article_report_mvt évite le double report depuis les lignes.';


--
-- Name: tr_crud_article_before(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_article_before() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_new_qte numeric(14, 3);
BEGIN IF TG_OP = 'INSERT' THEN v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(14, 3);
NEW."QteArticle" := v_new_qte;
CALL logistique.ps_crud_article(
    NEW."ID_Article",
    NEW."ID_TypeArticleFk",
    NEW."ID_CategorieArticleFk",
    NEW."ID_UniteFk",
    NULL,
    v_new_qte,
    'INSERT'
);
RETURN NEW;
END IF;
IF TG_OP = 'UPDATE' THEN NEW."QteArticle" := COALESCE(NEW."QteArticle", 0)::numeric(14, 3);
CALL logistique.ps_crud_article(
    NEW."ID_Article",
    NEW."ID_TypeArticleFk",
    NEW."ID_CategorieArticleFk",
    NEW."ID_UniteFk",
    COALESCE(OLD."QteArticle", 0)::numeric(14, 3),
    NEW."QteArticle",
    'UPDATE'
);
RETURN NEW;
END IF;
IF TG_OP = 'DELETE' THEN IF EXISTS (
    SELECT 1
    FROM logistique."T_CommandeDetail" cd
    WHERE cd."ID_ArticleFk" = OLD."ID_Article"
) THEN RAISE EXCEPTION 'tr_crud_article(DELETE) : suppression interdite, article % lie a T_CommandeDetail.',
OLD."ID_Article";
END IF;
IF EXISTS (
    SELECT 1
    FROM logistique."T_Mouvement" m
    WHERE m."ID_ArticleFk" = OLD."ID_Article"
) THEN RAISE EXCEPTION 'tr_crud_article(DELETE) : suppression interdite, article % lie a T_Mouvement.',
OLD."ID_Article";
END IF;
RETURN OLD;
END IF;
RETURN NEW;
END;
$$;


--
-- Name: FUNCTION tr_crud_article_before(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_article_before() IS 'Avant INSERT/UPDATE, normalise la quantité absente à zéro et appelle ps_crud_article. Avant DELETE, bloque la suppression d’un article lié à une ligne ou un mouvement.';


--
-- Name: tr_crud_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_commande() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF TG_OP = 'INSERT' THEN CALL logistique.ps_crud_commande(
        NEW."ID_Commande",
        NULL,
        NEW."ID_TypeCmdFk",
        NEW."ID_StatutCmdFk",
        NEW."ID_ConditionPaiementFk",
        NEW."ID_ModePaiementFk",
        'INSERT'
    );
RETURN NEW;
END IF;
IF TG_OP = 'UPDATE' THEN CALL logistique.ps_crud_commande(
    NEW."ID_Commande",
    OLD."ID_TypeCmdFk",
    NEW."ID_TypeCmdFk",
    NEW."ID_StatutCmdFk",
    NEW."ID_ConditionPaiementFk",
    NEW."ID_ModePaiementFk",
    'UPDATE'
);
RETURN NEW;
END IF;
RETURN NEW;
END;
$$;


--
-- Name: FUNCTION tr_crud_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_commande() IS 'Fonction de trigger AFTER INSERT/UPDATE transmettant anciens/nouveaux types et références à ps_crud_commande pour validation et réalignement des effets de stock.';


--
-- Name: tr_crud_commandedetail(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_commandedetail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF TG_OP = 'INSERT' THEN CALL logistique.ps_crud_commandeDetail(
        NULL,
        NULL,
        NULL,
        NULL,
        NEW."ID_CmdFk",
        NEW."ID_ArticleFk",
        NEW."QteCmdDetail",
        NEW."PUCmdDetail",
        'INSERT'
    );
RETURN NEW;
END IF;
IF TG_OP = 'UPDATE' THEN CALL logistique.ps_crud_commandeDetail(
    OLD."ID_CmdFk",
    OLD."ID_ArticleFk",
    OLD."QteCmdDetail",
    OLD."PUCmdDetail",
    NEW."ID_CmdFk",
    NEW."ID_ArticleFk",
    NEW."QteCmdDetail",
    NEW."PUCmdDetail",
    'UPDATE'
);
RETURN NEW;
END IF;
IF TG_OP = 'DELETE' THEN CALL logistique.ps_crud_commandeDetail(
    OLD."ID_CmdFk",
    OLD."ID_ArticleFk",
    OLD."QteCmdDetail",
    OLD."PUCmdDetail",
    NULL,
    NULL,
    NULL,
    NULL,
    'DELETE'
);
RETURN OLD;
END IF;
RETURN NEW;
END;
$$;


--
-- Name: FUNCTION tr_crud_commandedetail(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_commandedetail() IS 'Fonction commune des triggers de ligne : transmet OLD/NEW à ps_crud_commandedetail. Raccordée après INSERT/UPDATE et avant DELETE pour annuler l’ancien effet avant disparition de la ligne.';


--
-- Name: tr_crud_reglement(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_reglement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF TG_OP IN ('INSERT', 'UPDATE') THEN CALL logistique.ps_crud_reglement(
        NEW."ID_Reglement",
        NEW."ID_ModeReglementFk",
        TG_OP
    );
END IF;
IF TG_OP = 'DELETE' THEN RETURN OLD;
END IF;
RETURN NEW;
END;
$$;


--
-- Name: FUNCTION tr_crud_reglement(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_reglement() IS 'Fonction de trigger BEFORE INSERT/UPDATE validant le mode via ps_crud_reglement ; renvoie la ligne sans mise à jour des montants de facture.';


--
-- Name: tr_delete_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_delete_commande() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 CALL logistique.ps_crud_commande(OLD."ID_Commande",OLD."ID_TypeCmdFk",NULL,NULL,NULL,NULL,'DELETE');
 RETURN OLD;
END;$$;


--
-- Name: FUNCTION tr_delete_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_delete_commande() IS 'Compatibilité de la fonction historique non raccordée : utilise la signature courante à sept paramètres. La cascade des lignes assure les effets stock.';


--
-- Name: tr_guard_commandedetail(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_guard_commandedetail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
 v_ids integer[];
 v_commande record;
 v_nouvelle_trouvee boolean := false;
BEGIN
 IF TG_OP = 'INSERT' THEN v_ids := ARRAY[NEW."ID_CmdFk"];
 ELSIF TG_OP = 'UPDATE' THEN v_ids := ARRAY[OLD."ID_CmdFk", NEW."ID_CmdFk"];
 ELSE v_ids := ARRAY[OLD."ID_CmdFk"];
 END IF;
 -- Verrou commun avant l'effet stock et le futur calcul des totaux.
 -- L'ordre stable évite les inversions lors d'un déplacement entre commandes.
 FOR v_commande IN
  SELECT c."ID_Commande", c."StatusFacture"
  FROM logistique."T_Commande" c
  WHERE c."ID_Commande" = ANY(v_ids)
  ORDER BY c."ID_Commande"
  FOR NO KEY UPDATE
 LOOP
  IF logistique.fn_commande_cloturee(v_commande."StatusFacture") THEN
   RAISE EXCEPTION 'Commande % clôturée : modification de ses lignes interdite.', v_commande."ID_Commande"
    USING ERRCODE = '23514';
  END IF;
  IF TG_OP <> 'DELETE' AND v_commande."ID_Commande" = NEW."ID_CmdFk" THEN
   v_nouvelle_trouvee := true;
  END IF;
 END LOOP;
 IF TG_OP <> 'DELETE' AND NOT v_nouvelle_trouvee THEN
  RAISE EXCEPTION 'Commande % introuvable.', NEW."ID_CmdFk" USING ERRCODE = '23503';
 END IF;
 -- Lors du DELETE en cascade, le parent peut déjà avoir disparu ; son
 -- propre verrou de clôture a alors été contrôlé avant la suppression.
 IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;


--
-- Name: FUNCTION tr_guard_commandedetail(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_guard_commandedetail() IS 'Avant chaque mutation de ligne, verrouille les commandes concernées par identifiant croissant et refuse les commandes clôturées. Sérialise les saisies pour éviter les totaux perdus ; accepte la disparition du parent lors d’un DELETE en cascade déjà autorisé.';


--
-- Name: tr_lock_commande_cloturee(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_lock_commande_cloturee() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF logistique.fn_commande_cloturee(OLD."StatusFacture") THEN
  RAISE EXCEPTION 'Commande % clôturée : modification ou suppression interdite.', OLD."ID_Commande"
   USING ERRCODE = '23514';
 END IF;
 IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;


--
-- Name: FUNCTION tr_lock_commande_cloturee(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_lock_commande_cloturee() IS 'Avant UPDATE/DELETE de commande, refuse une commande clôturée selon le prédicat commun normalisé fn_commande_cloturee ; contrôle l’état OLD.';


--
-- Name: tr_lock_mouvement_direct(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_lock_mouvement_direct() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF COALESCE(
        current_setting('logistique.allow_t_mouvement_write', true),
        'off'
    ) = 'on' THEN IF TG_OP = 'DELETE' THEN RETURN OLD;
END IF;
PERFORM logistique.fn_assert_generique_category(
    NEW."ID_TypeMvtFk",
    64,
    format('tr_lock_mouvement_direct(%s)', TG_OP),
    'ID_TypeMvtFk'
);
RETURN NEW;
END IF;
RAISE EXCEPTION 'T_Mouvement est geree par la logique metier. Ecriture directe interdite.';
END;
$$;


--
-- Name: FUNCTION tr_lock_mouvement_direct(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_lock_mouvement_direct() IS 'Bloque les écritures sur T_Mouvement sauf si le drapeau transactionnel logistique.allow_t_mouvement_write vaut on ; valide alors la catégorie 64 du type pour INSERT/UPDATE.';


--
-- Name: tr_totaux_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_totaux_commande() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_id integer;
BEGIN
 IF TG_OP = 'INSERT' THEN
  FOR v_id IN SELECT DISTINCT "ID_CmdFk" FROM lignes_nouvelles ORDER BY "ID_CmdFk"
  LOOP CALL logistique.ps_update_totaux_commande(v_id); END LOOP;
 ELSIF TG_OP = 'DELETE' THEN
  FOR v_id IN SELECT DISTINCT "ID_CmdFk" FROM lignes_anciennes ORDER BY "ID_CmdFk"
  LOOP CALL logistique.ps_update_totaux_commande(v_id); END LOOP;
 ELSIF TG_OP = 'UPDATE' THEN
  FOR v_id IN
   SELECT "ID_CmdFk" FROM lignes_anciennes
   UNION SELECT "ID_CmdFk" FROM lignes_nouvelles ORDER BY "ID_CmdFk"
  LOOP CALL logistique.ps_update_totaux_commande(v_id); END LOOP;
 END IF;
 RETURN NULL;
END;
$$;


--
-- Name: FUNCTION tr_totaux_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_totaux_commande() IS 'Fonction des trois triggers AFTER STATEMENT de lignes : utilise les tables de transition pour recalculer une seule fois chaque commande affectée, y compris ancien/nouveau parent en UPDATE. Aucune boucle de recalcul par ligne.';


--
-- Name: archive_paiements(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.archive_paiements() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO operations."T_Paiement_Archive" (
        "IdPaiement",
        "CodePaiement",
        "IdUserFk",
        "IdTypePaiementFk",
        "MontantPaiement",
        "IdStatutPaiementFk",
        "DatePaiement",
        "ObsPaiement",
        "ValidePaiement",
        "IdDeviseFk",
        "IdPayeurFk",
        "IdTypeMouvementFk",
        "DateArchivage",
        "IdEntiteFk"
    )
    SELECT
        p."IdPaiement",
        p."CodePaiement",
        p."IdUserFk",
        p."IdTypePaiementFk",
        p."MontantPaiement",
        p."IdStatutPaiementFk",
        p."DatePaiement",
        p."ObsPaiement",
        p."ValidePaiement",
        p."IdDeviseFk",
        p."IdPayeurFk",
        p."IdTypeMouvementFk",
        NOW() AS "DateArchivage",
        p."IdEntiteFk"
    FROM operations."T_Paiement" p
    WHERE p."DatePaiement" < NOW() - INTERVAL '2 years';

    DELETE FROM operations."T_Paiement"
    WHERE "DatePaiement" < NOW() - INTERVAL '2 years';

    RETURN NULL;
END;
$$;


--
-- Name: FUNCTION archive_paiements(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.archive_paiements() IS 'Après INSERT/UPDATE sur T_Paiement, copie les paiements âgés de plus de deux ans dans T_Paiement_Archive, puis les supprime de la table active. Déclenchement par instruction, sans planification périodique ; les triggers de suppression de la table active restent applicables.';


--
-- Name: fn_audit_caisse(integer, integer, timestamp without time zone); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_audit_caisse(p_id_entite integer DEFAULT NULL::integer, p_id_devise integer DEFAULT NULL::integer, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("IdEntite" integer, "NomEntite" character varying, "IdDevise" integer, "NomDevise" character varying, "SoldeCaisse" numeric, "SoldeTheorique" numeric, "Ecart" numeric, "NbPaiements" integer, "MontantEntree" numeric, "MontantSortie" numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH paiements_union AS (
        -- Unification paiements actifs + archivés, avec filtre sur date si fourni
        SELECT
            p."IdDeviseFk"       AS IdDevise,
            p."IdEntiteFk"       AS IdEntite,
            p."IdTypeMouvementFk",
            p."MontantPaiement",
            p."IdStatutPaiementFk",
            p."DatePaiement"
        FROM operations."T_Paiement" p

        UNION ALL

        SELECT
            pa."IdDeviseFk"      AS IdDevise,
            pa."IdEntiteFk"      AS IdEntite,
            pa."IdTypeMouvementFk",
            pa."MontantPaiement",
            pa."IdStatutPaiementFk",
            pa."DatePaiement"
        FROM operations."T_Paiement_Archive" pa
    ),
    flux AS (
        SELECT
            u.IdDevise,
            u.IdEntite,
            COUNT(*) FILTER (
                WHERE u."IdStatutPaiementFk" = 21
                  AND u."IdTypeMouvementFk" IN (80, 81)
                  AND u."IdDevise" IN (36, 37)
            )                          AS nb_paiements,
            SUM(
                CASE
                    WHEN u."IdStatutPaiementFk" = 21
                     AND u."IdTypeMouvementFk" = 81
                     AND u."IdDevise" IN (36, 37)
                        AND (p_date_max IS NULL OR u."DatePaiement" <= p_date_max)
                        THEN u."MontantPaiement"
                    ELSE 0
                END
            )                          AS montant_entree,
            SUM(
                CASE
                    WHEN u."IdStatutPaiementFk" = 21
                     AND u."IdTypeMouvementFk" = 80
                     AND u."IdDevise" IN (36, 37)
                        AND (p_date_max IS NULL OR u."DatePaiement" <= p_date_max)
                        THEN u."MontantPaiement"
                    ELSE 0
                END
            )                          AS montant_sortie
        FROM paiements_union u
        WHERE (p_id_entite IS NULL OR u.IdEntite = p_id_entite)
          AND (p_id_devise IS NULL OR u.IdDevise = p_id_devise)
        GROUP BY
            u.IdDevise,
            u.IdEntite
    )
    SELECT
        ent."IdEntite"                    AS "IdEntite",
        ent."NomEntite"                   AS "NomEntite",
        dev."ID_Generique"                AS "IdDevise",
        dev."NomGenerique"                AS "NomDevise",

        COALESCE(c."MontantCaisse", 0)::numeric                        AS "SoldeCaisse",

        COALESCE(
            (COALESCE(f.montant_entree, 0) - COALESCE(f.montant_sortie, 0)),
            0
        )::numeric                                                     AS "SoldeTheorique",

        COALESCE(c."MontantCaisse", 0)::numeric
          - COALESCE(
                (COALESCE(f.montant_entree, 0) - COALESCE(f.montant_sortie, 0)),
                0
            )::numeric                                                 AS "Ecart",

        COALESCE(f.nb_paiements, 0)::integer                           AS "NbPaiements",
        COALESCE(f.montant_entree, 0)::numeric                         AS "MontantEntree",
        COALESCE(f.montant_sortie, 0)::numeric                         AS "MontantSortie"

    FROM operations."T_Caisse" c
    LEFT JOIN flux f
           ON f.IdDevise = c."IdDeviseFk"
          AND f.IdEntite = c."IdEntiteFk"
    LEFT JOIN referentiel."T_Generique" dev
           ON dev."ID_Generique" = c."IdDeviseFk"
    LEFT JOIN systeme."T_Entite" ent
           ON ent."IdEntite" = c."IdEntiteFk"
    WHERE (p_id_entite IS NULL OR c."IdEntiteFk" = p_id_entite)
      AND (p_id_devise IS NULL OR c."IdDeviseFk" = p_id_devise)
    ORDER BY
        ent."NomEntite",
        dev."NomGenerique";
END;
$$;


--
-- Name: FUNCTION fn_audit_caisse(p_id_entite integer, p_id_devise integer, p_date_max timestamp without time zone); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_audit_caisse(p_id_entite integer, p_id_devise integer, p_date_max timestamp without time zone) IS 'Lecture de rapprochement par caisse entité/devise entre solde courant et flux de T_Paiement UNION ALL T_Paiement_Archive. La définition utilise les identifiants fixes statut 21, entrée 81, sortie 80 et devises 36/37 ; p_date_max borne les sommes, pas le compteur. Ne reconstitue pas le solde courant à une date passée et ne partage pas exactement les critères de gestion_caisse_on_paiement.';


--
-- Name: fn_audit_flux_caisse(integer, integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_audit_flux_caisse(p_id_entite integer DEFAULT NULL::integer, p_id_devise integer DEFAULT NULL::integer, p_date_min timestamp without time zone DEFAULT NULL::timestamp without time zone, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("DateJour" timestamp without time zone, "IdEntite" integer, "NomEntite" character varying, "IdDevise" integer, "NomDevise" character varying, "MontantEntree" numeric, "MontantSortie" numeric, "NetJour" numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE_TRUNC('day', p."DatePaiement") AS "DateJour",
        p."IdEntiteFk"                      AS "IdEntite",
        ent."NomEntite"                     AS "NomEntite",
        p."IdDeviseFk"                      AS "IdDevise",
        dev."NomGenerique"                  AS "NomDevise",

        SUM(
            CASE
                WHEN p."IdStatutPaiementFk" = 21
                 AND p."IdTypeMouvementFk" = 81
                    THEN p."MontantPaiement"
                ELSE 0
            END
        )::numeric                          AS "MontantEntree",

        SUM(
            CASE
                WHEN p."IdStatutPaiementFk" = 21
                 AND p."IdTypeMouvementFk" = 80
                    THEN p."MontantPaiement"
                ELSE 0
            END
        )::numeric                          AS "MontantSortie",

        SUM(
            CASE
                WHEN p."IdStatutPaiementFk" = 21
                 AND p."IdTypeMouvementFk" = 81
                    THEN p."MontantPaiement"
                WHEN p."IdStatutPaiementFk" = 21
                 AND p."IdTypeMouvementFk" = 80
                    THEN -p."MontantPaiement"
                ELSE 0
            END
        )::numeric                          AS "NetJour"

    FROM operations."T_Paiement" p
    LEFT JOIN referentiel."T_Generique" dev
           ON dev."ID_Generique" = p."IdDeviseFk"
    LEFT JOIN systeme."T_Entite" ent
           ON ent."IdEntite" = p."IdEntiteFk"
    WHERE (p_id_entite IS NULL OR p."IdEntiteFk" = p_id_entite)
      AND (p_id_devise IS NULL OR p."IdDeviseFk" = p_id_devise)
      AND (p_date_min IS NULL OR p."DatePaiement" >= p_date_min)
      AND (p_date_max IS NULL OR p."DatePaiement" <= p_date_max)
    GROUP BY
        DATE_TRUNC('day', p."DatePaiement"),
        p."IdEntiteFk",
        ent."NomEntite",
        p."IdDeviseFk",
        dev."NomGenerique"
    ORDER BY
        "DateJour",
        "NomEntite",
        "NomDevise";
END;
$$;


--
-- Name: FUNCTION fn_audit_flux_caisse(p_id_entite integer, p_id_devise integer, p_date_min timestamp without time zone, p_date_max timestamp without time zone); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_audit_flux_caisse(p_id_entite integer, p_id_devise integer, p_date_min timestamp without time zone, p_date_max timestamp without time zone) IS 'Lecture des flux journaliers par entité/devise, avec bornes inclusives optionnelles ; lit seulement T_Paiement, sans archives. Les contributions utilisent le statut 21 et les mouvements 81/80 ; net = entrées moins sorties.';


--
-- Name: gestion_caisse_on_paiement(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.gestion_caisse_on_paiement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Deltas à appliquer sur la caisse
    v_delta_old NUMERIC := 0;
    v_delta_new NUMERIC := 0;

    -- Variables de travail
    v_sign       INTEGER;
    v_is_paid    BOOLEAN;
    v_is_devise  BOOLEAN;
BEGIN
    --------------------------------------------------------------------
    -- 1) TRAITEMENT DE L'ANCIEN ENREGISTREMENT (OLD) → DELETE / UPDATE
    --------------------------------------------------------------------
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_delta_old := 0;
        v_sign      := 0;
        v_is_paid   := FALSE;
        v_is_devise := FALSE;

        -- a) Statut paiement = 'Payé(e)' dans catégorie 'Statut paiement' ?
        IF OLD."IdStatutPaiementFk" IS NOT NULL THEN
            SELECT
                ( lower(cg."NomCategorieGenerique") = 'statut paiement'
                  AND trim(g."NomGenerique") = 'Payé(e)' )
            INTO v_is_paid
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdStatutPaiementFk";
        END IF;

        -- b) Devise appartenant à la catégorie 'Devise' ?
        IF OLD."IdDeviseFk" IS NOT NULL THEN
            SELECT
                ( lower(cg."NomCategorieGenerique") = 'devise' )
            INTO v_is_devise
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdDeviseFk";
        END IF;

        -- c) Type mouvement paiement : 'Entrée' / 'Sortie' ?
        IF OLD."IdTypeMouvementFk" IS NOT NULL THEN
            SELECT
                CASE
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'entr%' THEN  1   -- Entrée
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'sort%' THEN -1   -- Sortie
                    ELSE 0
                END
            INTO v_sign
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdTypeMouvementFk";
        END IF;

        -- d) Calcul de l'effet OLD sur la caisse (qu'on doit annuler)
        IF OLD."ValidePaiement" IS TRUE
           AND v_is_paid
           AND v_is_devise
           AND v_sign <> 0
           AND OLD."IdEntiteFk" IS NOT NULL
        THEN
            -- Pour un DELETE ou la "sortie" de l'ancien état :
            -- delta_old = - (signe * MontantPaiement)
            v_delta_old := - v_sign * OLD."MontantPaiement";

            -- Appliquer delta_old à la caisse correspondante
            INSERT INTO operations."T_Caisse" AS c (
                "IdEntiteFk", "IdDeviseFk", "MontantCaisse"
            )
            VALUES (
                OLD."IdEntiteFk",
                OLD."IdDeviseFk",
                v_delta_old
            )
            ON CONFLICT ("IdEntiteFk", "IdDeviseFk")
            DO UPDATE
            SET "MontantCaisse" = c."MontantCaisse" + EXCLUDED."MontantCaisse";
        END IF;
    END IF;

    --------------------------------------------------------------------
    -- 2) TRAITEMENT DU NOUVEL ENREGISTREMENT (NEW) → INSERT / UPDATE
    --------------------------------------------------------------------
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_delta_new := 0;
        v_sign      := 0;
        v_is_paid   := FALSE;
        v_is_devise := FALSE;

        -- a) Statut paiement = 'Payé(e)' ?
        IF NEW."IdStatutPaiementFk" IS NOT NULL THEN
            SELECT
                ( lower(cg."NomCategorieGenerique") = 'statut paiement'
                  AND trim(g."NomGenerique") = 'Payé(e)' )
            INTO v_is_paid
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdStatutPaiementFk";
        END IF;

        -- b) Devise appartenant à la catégorie 'Devise' ?
        IF NEW."IdDeviseFk" IS NOT NULL THEN
            SELECT
                ( lower(cg."NomCategorieGenerique") = 'devise' )
            INTO v_is_devise
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdDeviseFk";
        END IF;

        -- c) Type mouvement : 'Entrée' / 'Sortie' ?
        IF NEW."IdTypeMouvementFk" IS NOT NULL THEN
            SELECT
                CASE
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'entr%' THEN  1
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'sort%' THEN -1
                    ELSE 0
                END
            INTO v_sign
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdTypeMouvementFk";
        END IF;

        -- d) Calcul de l'effet NEW sur la caisse
        IF NEW."ValidePaiement" IS TRUE
           AND v_is_paid
           AND v_is_devise
           AND v_sign <> 0
           AND NEW."IdEntiteFk" IS NOT NULL
        THEN
            -- Pour un INSERT ou la "nouvelle" version en UPDATE :
            -- delta_new = signe * MontantPaiement
            v_delta_new := v_sign * NEW."MontantPaiement";

            -- Appliquer delta_new à la caisse correspondante
            INSERT INTO operations."T_Caisse" AS c (
                "IdEntiteFk", "IdDeviseFk", "MontantCaisse"
            )
            VALUES (
                NEW."IdEntiteFk",
                NEW."IdDeviseFk",
                v_delta_new
            )
            ON CONFLICT ("IdEntiteFk", "IdDeviseFk")
            DO UPDATE
            SET "MontantCaisse" = c."MontantCaisse" + EXCLUDED."MontantCaisse";
        END IF;
    END IF;

    -- 3) Retour standard pour un trigger AFTER ROW
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


--
-- Name: FUNCTION gestion_caisse_on_paiement(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.gestion_caisse_on_paiement() IS 'Après mutation d’un paiement, annule l’effet OLD et applique NEW dans la caisse entité/devise par UPSERT. Éligibilité : ValidePaiement vrai, statut Payé(e), catégorie devise, type de mouvement paiement Entrée/Sortie et entité renseignée. Les libellés de référentiel sont utilisés, contrairement aux codes fixes des fonctions d’audit.';


--
-- Name: notification_payment_success(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.notification_payment_success() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE 
    utilisateur_id INT;
    montant        NUMERIC(10,2);
    devise_nom     VARCHAR;
    statut_nom     VARCHAR;
    mouvement_nom  VARCHAR;
    type_notif     INT;
BEGIN
    -- Récupérer les libellés associés aux IDs (statut, devise, type de mouvement)
    SELECT "NomGenerique"
    INTO statut_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdStatutPaiementFk";

    SELECT "NomGenerique"
    INTO devise_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdDeviseFk";

    SELECT "NomGenerique"
    INTO mouvement_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdTypeMouvementFk";

    -- Récupérer le type de communication "Notification"
    SELECT "ID_Generique"
    INTO type_notif
    FROM referentiel."T_Generique"
    WHERE "NomGenerique" = 'Notification';

    utilisateur_id := NEW."IdUserFk";
    montant        := NEW."MontantPaiement";
    
    -- Vérifier que le statut n'est pas "En attente"
    IF statut_nom NOT IN ('En attente') THEN
        INSERT INTO communication."T_Communication" (
            "IdUserFk",
            "IdTypeCommunication",
            "ContenuCommunication",
            "DateCommunication",
            "ValideCommunication",
            "LectureCommunication",
            "IdEntiteFk"
        )
        VALUES (
            utilisateur_id, 
            type_notif, 
            'Votre paiement de ' || montant || ' ' || devise_nom ||
            ' a été reçu avec succès. Statut: ' || statut_nom ||
            ', Mouvement: ' || mouvement_nom || '.',
            NOW(),
            TRUE,
            FALSE,
            NEW."IdEntiteFk"
        );
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION notification_payment_success(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.notification_payment_success() IS 'Après INSERT/UPDATE du paiement, ajoute une communication à son utilisateur si le libellé de statut n’est pas En attente. Ne vérifie pas une transition vers payé ni l’absence d’une notification précédente ; le nom de la fonction ne certifie pas un paiement réussi.';


--
-- Name: prevent_delete_caisse_if_dependent(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.prevent_delete_caisse_if_dependent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    ----------------------------------------------------------------------
    -- 1. Vérifier les dépendances dans operations."T_Paiement"
    --    On bloque si au moins un paiement existe pour cette entité/devise
    ----------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM operations."T_Paiement" p
        WHERE p."IdDeviseFk" = OLD."IdDeviseFk"
          AND p."IdEntiteFk" = OLD."IdEntiteFk"
    ) THEN
        RAISE EXCEPTION
            'Suppression impossible : des paiements existent pour cette caisse (Entité=% / Devise=%).',
            OLD."IdEntiteFk", OLD."IdDeviseFk";
    END IF;

    ----------------------------------------------------------------------
    -- 2. Vérifier les dépendances dans operations."T_Paiement_Archive"
    --    On bloque aussi si des paiements ARCHIVÉS existent
    ----------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM operations."T_Paiement_Archive" pa
        WHERE pa."IdDeviseFk" = OLD."IdDeviseFk"
          AND pa."IdEntiteFk" = OLD."IdEntiteFk"
    ) THEN
        RAISE EXCEPTION
            'Suppression impossible : des paiements archivés existent pour cette caisse (Entité=% / Devise=%).',
            OLD."IdEntiteFk", OLD."IdDeviseFk";
    END IF;

    ----------------------------------------------------------------------
    -- Si aucune dépendance → on autorise la suppression
    ----------------------------------------------------------------------
    RETURN OLD;
END;
$$;


--
-- Name: FUNCTION prevent_delete_caisse_if_dependent(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.prevent_delete_caisse_if_dependent() IS 'Avant DELETE de caisse, bloque la suppression s’il existe un paiement actif ou archivé pour le même couple entité/devise.';


--
-- Name: fn_guard_sens_stock(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_guard_sens_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
END;$$;


--
-- Name: FUNCTION fn_guard_sens_stock(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_guard_sens_stock() IS 'Protège le signe Entrée/Sortie et la catégorie 64 d’un type déjà utilisé par une commande ou un mouvement ; évite une réinterprétation rétroactive du stock. Un changement de libellé conservant le signe reste permis.';


--
-- Name: audit_log_function(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.audit_log_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE before_row jsonb; after_row jsonb; entity_id integer;
BEGIN
 IF TG_OP IN ('DELETE','UPDATE') THEN before_row:=systeme.fn_audit_sans_secrets(to_jsonb(OLD)); END IF;
 IF TG_OP IN ('INSERT','UPDATE') THEN after_row:=systeme.fn_audit_sans_secrets(to_jsonb(NEW)); END IF;
 entity_id:=coalesce((after_row->>'IdEntiteFk')::integer,(before_row->>'IdEntiteFk')::integer);
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk")
 VALUES(TG_TABLE_NAME,TG_OP,before_row,after_row,current_timestamp,entity_id);
 RETURN NULL;
END;$$;


--
-- Name: FUNCTION audit_log_function(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.audit_log_function() IS 'Audit AFTER INSERT/UPDATE/DELETE transactionnel : lit le contexte par JSON sans supposer une colonne IdEntiteFk, ne recopie ni mots de passe ni jetons et accepte une entité absente.';


--
-- Name: fn_admin_ui_setting_set_updated_at(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_admin_ui_setting_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW."UpdatedAt" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION fn_admin_ui_setting_set_updated_at(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_admin_ui_setting_set_updated_at() IS 'Avant UPDATE d’un paramètre d’interface, remplace UpdatedAt par CURRENT_TIMESTAMP et renvoie NEW.';


--
-- Name: fn_audit_sans_secrets(jsonb); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
 SELECT p_data - ARRAY['MotdepasseUser','password','Password','MotDePasse','accessToken','refreshToken'];
$$;


--
-- Name: FUNCTION fn_audit_sans_secrets(p_data jsonb); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) IS 'Retire les champs de mot de passe et jetons d’une image de ligne JSON d’audit ; conserve NULL et les autres données de traçabilité.';


--
-- Name: format_phone_number(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.format_phone_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW."PhoneUser" := regexp_replace(NEW."PhoneUser", '[^0-9]', '', 'g');
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION format_phone_number(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.format_phone_number() IS 'Avant INSERT/UPDATE d’un utilisateur, retire de PhoneUser tous les caractères autres que les chiffres. Ne normalise pas le préfixe international ni la validité téléphonique.';


--
-- Name: notify_licence_expiry(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.notify_licence_expiry() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
END;$$;


--
-- Name: FUNCTION notify_licence_expiry(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.notify_licence_expiry() IS 'À l’écriture d’une licence valide arrivant à J+7 calendaires, notifie un gestionnaire actif de la même entité. Une modification sans changement de date ni activation ne répète pas la notification. Ce trigger ne constitue pas une tâche quotidienne planifiée.';


--
-- Name: prevent_multiple_active_licenses(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.prevent_multiple_active_licenses() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
END;$$;


--
-- Name: FUNCTION prevent_multiple_active_licenses(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.prevent_multiple_active_licenses() IS 'Verrouille les entités dans un ordre stable et refuse tout chevauchement de périodes de licences déclarées valides, à l’insertion et à la mise à jour, y compris concurrentes. Les renouvellements sans chevauchement et licences désactivées restent autorisés.';


--
-- Name: prevention_delete_if_dependent(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.prevention_delete_if_dependent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_has_dependencies boolean := false;
BEGIN
    ----------------------------------------------------------------------
    -- 1) Vérifier la table T_Evaluations (si elle existe dans la base)
    ----------------------------------------------------------------------
    IF to_regclass('"T_Evaluations"') IS NOT NULL THEN
        PERFORM 1
        FROM "T_Evaluations" e
        WHERE e."IdCibleFk" = OLD."IdUser"
        LIMIT 1;

        IF FOUND THEN
            v_has_dependencies := true;
        END IF;
    END IF;

    ----------------------------------------------------------------------
    -- 2) Vérifier la table operations."T_Paiement" (nouveau schéma)
    ----------------------------------------------------------------------
    IF NOT v_has_dependencies
       AND to_regclass('operations."T_Paiement"') IS NOT NULL THEN

        PERFORM 1
        FROM operations."T_Paiement" p
        WHERE p."IdUserFk" = OLD."IdUser"
        LIMIT 1;

        IF FOUND THEN
            v_has_dependencies := true;
        END IF;
    END IF;

    ----------------------------------------------------------------------
    -- 3) Vérifier la table T_Presence (si elle existe dans la base)
    ----------------------------------------------------------------------
    IF NOT v_has_dependencies
       AND to_regclass('"T_Presence"') IS NOT NULL THEN

        PERFORM 1
        FROM "T_Presence" pr
        WHERE pr."IdControleFk" = OLD."IdUser"
        LIMIT 1;

        IF FOUND THEN
            v_has_dependencies := true;
        END IF;
    END IF;

    ----------------------------------------------------------------------
    -- 4) Si une dépendance est trouvée → bloquer la suppression
    ----------------------------------------------------------------------
    IF v_has_dependencies THEN
        RAISE EXCEPTION
            'Suppression impossible : cet utilisateur a des dépendances dans le système (paiements, présences ou évaluations).';
    END IF;

    RETURN OLD;
END;
$$;


--
-- Name: FUNCTION prevention_delete_if_dependent(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.prevention_delete_if_dependent() IS 'Avant DELETE utilisateur, bloque la suppression si des paiements liés par IdUserFk ou des présences/évaluations liées existent dans les tables que la fonction trouve. Ne couvre pas à elle seule toutes les dépendances : les contraintes FK restent applicables.';


--
-- Name: update_date_modification(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.update_date_modification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW."DateModificationUser" := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION update_date_modification(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.update_date_modification() IS 'Avant UPDATE utilisateur, remplace DateModificationUser par NOW() et renvoie NEW.';


--
-- Name: update_licence_status(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.update_licence_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW."ExpireeLicence":=NEW."DateFin"<=current_timestamp; RETURN NEW; END;$$;


--
-- Name: FUNCTION update_licence_status(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.update_licence_status() IS 'Calcule le drapeau d’expiration au moment de l’écriture. La vue calcule l’état courant à la lecture pour tenir compte du passage du temps.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Recherche; Type: TABLE; Schema: analytics; Owner: -
--

CREATE TABLE analytics."T_Recherche" (
    "IdRecherche" integer CONSTRAINT "T_Recherche_IdRecherche_not_null" NOT NULL,
    "IdUserFk" integer,
    "TexteRecherche" text CONSTRAINT "T_Recherche_TexteRecherche_not_null" NOT NULL,
    "TypeRecherche" character varying(80),
    "ID_ArticleResultFk" integer,
    "IdEntiteResultFk" integer,
    "IdSpecialiteFk" integer,
    "LatitudeUser" numeric(9,6),
    "LongitudeUser" numeric(9,6),
    "DateRecherche" timestamp with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Recherche_DateRecherche_not_null" NOT NULL,
    CONSTRAINT "T_Recherche_LatitudeUser_check" CHECK ((("LatitudeUser" >= ('-90'::integer)::numeric) AND ("LatitudeUser" <= (90)::numeric))),
    CONSTRAINT "T_Recherche_LongitudeUser_check" CHECK ((("LongitudeUser" >= ('-180'::integer)::numeric) AND ("LongitudeUser" <= (180)::numeric))),
    CONSTRAINT "T_Recherche_TexteRecherche_check" CHECK (((length(btrim("TexteRecherche")) >= 1) AND (length(btrim("TexteRecherche")) <= 1000)))
);


--
-- Name: TABLE "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON TABLE analytics."T_Recherche" IS 'Événements de recherche explicitement enregistrés par un service autorisé. Aucun suivi automatique ni historique fictif n’est activé par la création de ce socle. Accès administratif global ; appliquer une politique de conservation avant une collecte réelle.';


--
-- Name: COLUMN "T_Recherche"."IdRecherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."IdRecherche" IS 'Identifiant automatique de l’événement de recherche.';


--
-- Name: COLUMN "T_Recherche"."IdUserFk"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."IdUserFk" IS 'Utilisateur ayant initié la recherche si connu ; NULL après suppression de son compte.';


--
-- Name: COLUMN "T_Recherche"."TexteRecherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."TexteRecherche" IS 'Texte recherché non vide, limité à 1000 caractères ; peut contenir des données privées, donc accès restreint.';


--
-- Name: COLUMN "T_Recherche"."TypeRecherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."TypeRecherche" IS 'Qualification textuelle facultative du contexte de recherche ; ne remplace pas un résultat effectivement lié.';


--
-- Name: COLUMN "T_Recherche"."ID_ArticleResultFk"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."ID_ArticleResultFk" IS 'Article résultat de la recherche s’il existe ; NULL après suppression de cet article.';


--
-- Name: COLUMN "T_Recherche"."IdEntiteResultFk"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."IdEntiteResultFk" IS 'Structure résultat de la recherche ; ne constitue pas l’organisation propriétaire de l’événement.';


--
-- Name: COLUMN "T_Recherche"."IdSpecialiteFk"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."IdSpecialiteFk" IS 'Spécialité recherchée dans le référentiel si renseignée.';


--
-- Name: COLUMN "T_Recherche"."LatitudeUser"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."LatitudeUser" IS 'Latitude facultative en degrés décimaux, de -90 à 90 ; aucune collecte automatique n’est activée.';


--
-- Name: COLUMN "T_Recherche"."LongitudeUser"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."LongitudeUser" IS 'Longitude facultative en degrés décimaux, de -180 à 180 ; aucune collecte automatique n’est activée.';


--
-- Name: COLUMN "T_Recherche"."DateRecherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."DateRecherche" IS 'Horodatage avec fuseau de l’événement, attribué par PostgreSQL si absent.';


--
-- Name: CONSTRAINT "T_Recherche_IdRecherche_not_null" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_IdRecherche_not_null" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : NOT NULL "IdRecherche"';


--
-- Name: CONSTRAINT "T_Recherche_TexteRecherche_not_null" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_TexteRecherche_not_null" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : NOT NULL "TexteRecherche"';


--
-- Name: CONSTRAINT "T_Recherche_DateRecherche_not_null" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_DateRecherche_not_null" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : NOT NULL "DateRecherche"';


--
-- Name: CONSTRAINT "T_Recherche_LatitudeUser_check" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_LatitudeUser_check" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : CHECK ("LatitudeUser" >= ''-90''::integer::numeric AND "LatitudeUser" <= 90::numeric)';


--
-- Name: CONSTRAINT "T_Recherche_LongitudeUser_check" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_LongitudeUser_check" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : CHECK ("LongitudeUser" >= ''-180''::integer::numeric AND "LongitudeUser" <= 180::numeric)';


--
-- Name: CONSTRAINT "T_Recherche_TexteRecherche_check" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_TexteRecherche_check" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : CHECK (length(btrim("TexteRecherche")) >= 1 AND length(btrim("TexteRecherche")) <= 1000)';


--
-- Name: T_Recherche_IdRecherche_seq; Type: SEQUENCE; Schema: analytics; Owner: -
--

ALTER TABLE analytics."T_Recherche" ALTER COLUMN "IdRecherche" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME analytics."T_Recherche_IdRecherche_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Recherche_IdRecherche_seq"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON SEQUENCE analytics."T_Recherche_IdRecherche_seq" IS 'Séquence technique d’identité attribuant les identifiants sans réécrire les lignes existantes.';


--
-- Name: T_Article; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Article" (
    "ID_Article" integer CONSTRAINT "T_Article_ID_Article_not_null" NOT NULL,
    "ID_TypeArticleFk" integer,
    "ID_CategorieArticleFk" integer,
    "ID_UserFK" integer,
    "ID_UniteFk" integer,
    "DateHeureAuto" timestamp with time zone,
    "CodeArticleExterne" integer,
    "NomArticle" character varying(100) CONSTRAINT "T_Article_NomArticle_not_null" NOT NULL,
    "RefArticle" character varying(255),
    "QteArticle" numeric(14,3) DEFAULT 0 CONSTRAINT "T_Article_QteArticle_not_null" NOT NULL,
    "PUArticle" numeric(12,2) CONSTRAINT "T_Article_PUArticle_not_null" NOT NULL,
    "PVArticle" numeric(12,2) CONSTRAINT "T_Article_PVArticle_not_null" NOT NULL,
    "QteMinArticle" integer,
    "PhotoArticle" character varying(255),
    "ObsArticle" text,
    "ValideArticle" boolean DEFAULT true CONSTRAINT "T_Article_ValideArticle_not_null" NOT NULL,
    "DatePeremptionArticle" timestamp with time zone,
    "DatePeremptionAlerteArticle" timestamp with time zone,
    "NbreJoursAlerteArticle" integer,
    "CodeArticleInterne" character varying(243),
    CONSTRAINT chk_article_qte_non_negative CHECK ((("QteArticle" IS NULL) OR ("QteArticle" >= (0)::numeric))),
    CONSTRAINT chk_article_qtemin_non_negative CHECK ((("QteMinArticle" IS NULL) OR ("QteMinArticle" >= 0))),
    CONSTRAINT ck_article_prix_positifs CHECK (((("PUArticle" IS NULL) OR ("PUArticle" >= (0)::numeric)) AND (("PVArticle" IS NULL) OR ("PVArticle" >= (0)::numeric))))
);


--
-- Name: TABLE "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Article" IS 'Catalogue des articles et stock courant officiel QteArticle, avec prix, unité, seuil et péremption. Les triggers contrôlent les références et historisent les ajustements directs de quantité.';


--
-- Name: COLUMN "T_Article"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_Article" IS 'Identifiant de l’article.';


--
-- Name: COLUMN "T_Article"."ID_TypeArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_TypeArticleFk" IS 'Type d’article dans la nomenclature de catégorie 46. Relation imposée : FOREIGN KEY ("ID_TypeArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Article"."ID_CategorieArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_CategorieArticleFk" IS 'Catégorie de l’article dans la nomenclature de catégorie 40. Relation imposée : FOREIGN KEY ("ID_CategorieArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Article"."ID_UserFK"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_UserFK" IS 'Utilisateur rattaché à l’article. Relation imposée : FOREIGN KEY ("ID_UserFK") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE NOT VALID.';


--
-- Name: COLUMN "T_Article"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_UniteFk" IS 'Unité de référence de l’article, dans la nomenclature de catégorie 34. Relation imposée : FOREIGN KEY ("ID_UniteFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Article"."DateHeureAuto"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."DateHeureAuto" IS 'Horodatage automatique enregistré pour l’article.';


--
-- Name: COLUMN "T_Article"."CodeArticleExterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."CodeArticleExterne" IS 'Code de l’article dans un référentiel externe, enregistré sous forme entière.';


--
-- Name: COLUMN "T_Article"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."NomArticle" IS 'Libellé de l’article.';


--
-- Name: COLUMN "T_Article"."RefArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."RefArticle" IS 'Référence descriptive complémentaire de l’article.';


--
-- Name: COLUMN "T_Article"."QteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."QteArticle" IS 'Stock courant officiel de l’article dans son unité de référence ; malgré le type décimal, les routines actuelles refusent les effets fractionnaires historisés en mouvements entiers.';


--
-- Name: COLUMN "T_Article"."PUArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."PUArticle" IS 'Prix unitaire d’achat enregistré sur l’article ; la devise n’est pas portée par cette table.';


--
-- Name: COLUMN "T_Article"."PVArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."PVArticle" IS 'Prix unitaire de vente enregistré sur l’article ; la devise n’est pas portée par cette table.';


--
-- Name: COLUMN "T_Article"."QteMinArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."QteMinArticle" IS 'Seuil minimal de stock de l’article ; NULL signifie absence de seuil renseigné.';


--
-- Name: COLUMN "T_Article"."PhotoArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."PhotoArticle" IS 'Référence de la photo de l’article.';


--
-- Name: COLUMN "T_Article"."ObsArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ObsArticle" IS 'Observations enregistrées sur l’article.';


--
-- Name: COLUMN "T_Article"."ValideArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ValideArticle" IS 'Indique si l’article est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Article"."DatePeremptionArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."DatePeremptionArticle" IS 'Date de péremption enregistrée pour l’article ; absence conservée comme date non renseignée dans la qualification.';


--
-- Name: COLUMN "T_Article"."DatePeremptionAlerteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."DatePeremptionAlerteArticle" IS 'Date explicite de début d’alerte avant péremption ; utilisée par les vues avec le délai d’alerte.';


--
-- Name: COLUMN "T_Article"."NbreJoursAlerteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."NbreJoursAlerteArticle" IS 'Nombre de jours avant péremption déclenchant une alerte dans la vue article.';


--
-- Name: COLUMN "T_Article"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."CodeArticleInterne" IS 'Référence interne unique de l’article.';


--
-- Name: CONSTRAINT "T_Article_ID_Article_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_ID_Article_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "ID_Article".';


--
-- Name: CONSTRAINT "T_Article_NomArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_NomArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "NomArticle".';


--
-- Name: CONSTRAINT "T_Article_QteArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_QteArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "QteArticle".';


--
-- Name: CONSTRAINT "T_Article_PUArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_PUArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "PUArticle".';


--
-- Name: CONSTRAINT "T_Article_PVArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_PVArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "PVArticle".';


--
-- Name: CONSTRAINT "T_Article_ValideArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_ValideArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "ValideArticle".';


--
-- Name: CONSTRAINT chk_article_qte_non_negative ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_article_qte_non_negative ON logistique."T_Article" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Article". Définition : CHECK ("QteArticle" IS NULL OR "QteArticle" >= 0::numeric).';


--
-- Name: CONSTRAINT chk_article_qtemin_non_negative ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_article_qtemin_non_negative ON logistique."T_Article" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Article". Définition : CHECK ("QteMinArticle" IS NULL OR "QteMinArticle" >= 0).';


--
-- Name: CONSTRAINT ck_article_prix_positifs ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_article_prix_positifs ON logistique."T_Article" IS 'Intégrité imposée par PostgreSQL : CHECK (("PUArticle" IS NULL OR "PUArticle" >= 0::numeric) AND ("PVArticle" IS NULL OR "PVArticle" >= 0::numeric))';


--
-- Name: V_Recherche; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics."V_Recherche" AS
 SELECT a."ID_Article",
    a."NomArticle",
    count(r."IdRecherche") AS nbrerecherches
   FROM (analytics."T_Recherche" r
     JOIN logistique."T_Article" a ON ((a."ID_Article" = r."ID_ArticleResultFk")))
  GROUP BY a."ID_Article", a."NomArticle";


--
-- Name: VIEW "V_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON VIEW analytics."V_Recherche" IS 'Nombre d’événements réellement enregistrés par article résultat, au grain article. Les événements sans article et les articles sans recherche ne produisent pas de ligne ; aucun total fictif.';


--
-- Name: COLUMN "V_Recherche"."ID_Article"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."V_Recherche"."ID_Article" IS 'Article résultat, clé du grain de l’agrégat.';


--
-- Name: COLUMN "V_Recherche"."NomArticle"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."V_Recherche"."NomArticle" IS 'Nom courant de l’article résultat.';


--
-- Name: COLUMN "V_Recherche".nbrerecherches; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."V_Recherche".nbrerecherches IS 'Nombre exact de lignes de T_Recherche liées à cet article ; ne représente ni les utilisateurs distincts ni les ventes.';


--
-- Name: T_Chat; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Chat" (
    "IdChat" integer CONSTRAINT "T_Chat_IdChat_not_null" NOT NULL,
    "TextChat" text,
    "ChatFile" text,
    "ChatLink" text,
    "AuthorIdFk" integer,
    "IdDiscussionFk" integer,
    "DateChat" timestamp with time zone DEFAULT now() CONSTRAINT "T_Chat_DateChat_not_null" NOT NULL,
    "LuChat" boolean DEFAULT false CONSTRAINT "T_Chat_LuChat_not_null" NOT NULL,
    CONSTRAINT ck_chat_contenu_non_vide CHECK (((NULLIF(btrim("TextChat"), ''::text) IS NOT NULL) OR (NULLIF(btrim("ChatFile"), ''::text) IS NOT NULL) OR (NULLIF(btrim("ChatLink"), ''::text) IS NOT NULL)))
);


--
-- Name: TABLE "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Chat" IS 'Messages des discussions : texte, pièce ou lien, auteur, discussion, date et indicateur de lecture. Grain : un message identifié par IdChat.';


--
-- Name: COLUMN "T_Chat"."IdChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."IdChat" IS 'Identifiant du message.';


--
-- Name: COLUMN "T_Chat"."TextChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."TextChat" IS 'Texte du message de discussion.';


--
-- Name: COLUMN "T_Chat"."ChatFile"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."ChatFile" IS 'Référence de la pièce jointe au message.';


--
-- Name: COLUMN "T_Chat"."ChatLink"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."ChatLink" IS 'Lien associé au message.';


--
-- Name: COLUMN "T_Chat"."AuthorIdFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."AuthorIdFk" IS 'Utilisateur auteur du message. Relation imposée : FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Chat"."IdDiscussionFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."IdDiscussionFk" IS 'Discussion contenant le message. Relation imposée : FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: COLUMN "T_Chat"."DateChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."DateChat" IS 'Date et heure du message avec fuseau horaire.';


--
-- Name: COLUMN "T_Chat"."LuChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."LuChat" IS 'Indicateur de lecture enregistré sur le message.';


--
-- Name: CONSTRAINT "T_Chat_IdChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_IdChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "IdChat".';


--
-- Name: CONSTRAINT "T_Chat_DateChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_DateChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "DateChat".';


--
-- Name: CONSTRAINT "T_Chat_LuChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_LuChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "LuChat".';


--
-- Name: CONSTRAINT ck_chat_contenu_non_vide ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_chat_contenu_non_vide ON communication."T_Chat" IS 'Intégrité imposée par PostgreSQL : CHECK (NULLIF(btrim("TextChat"), ''''::text) IS NOT NULL OR NULLIF(btrim("ChatFile"), ''''::text) IS NOT NULL OR NULLIF(btrim("ChatLink"), ''''::text) IS NOT NULL)';


--
-- Name: T_Chat_IdChat_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Chat" ALTER COLUMN "IdChat" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Chat_IdChat_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Chat_IdChat_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Chat_IdChat_seq" IS 'Séquence de génération de "communication"."T_Chat"."IdChat". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Communication; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Communication" (
    "IdCommunication" integer CONSTRAINT "T_Communication_IdCommunication_not_null" NOT NULL,
    "IdUserFk" integer,
    "IdTypeCommunication" integer,
    "ContenuCommunication" text,
    "DateCommunication" timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Communication_DateCommunication_not_null" NOT NULL,
    "ObsCommunication" text,
    "ValideCommunication" boolean DEFAULT true CONSTRAINT "T_Communication_ValideCommunication_not_null" NOT NULL,
    "LectureCommunication" boolean DEFAULT false CONSTRAINT "T_Communication_LectureCommunication_not_null" NOT NULL,
    "IdEntiteFk" integer
);


--
-- Name: TABLE "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Communication" IS 'Communications et notifications destinées à un utilisateur, éventuellement rattachées à une entité ; contenu, type, date, validité et lecture. Distinctes des messages de discussion.';


--
-- Name: COLUMN "T_Communication"."IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdCommunication" IS 'Identifiant de la communication ou notification.';


--
-- Name: COLUMN "T_Communication"."IdUserFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Communication"."IdTypeCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdTypeCommunication" IS 'Type de communication dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Communication"."ContenuCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ContenuCommunication" IS 'Texte de la communication ou notification destinée à l’utilisateur.';


--
-- Name: COLUMN "T_Communication"."DateCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."DateCommunication" IS 'Date et heure d’enregistrement de la communication.';


--
-- Name: COLUMN "T_Communication"."ObsCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ObsCommunication" IS 'Observations enregistrées sur la communication.';


--
-- Name: COLUMN "T_Communication"."ValideCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ValideCommunication" IS 'Indique si la communication est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Communication"."LectureCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."LectureCommunication" IS 'Indique si la communication est marquée comme lue.';


--
-- Name: COLUMN "T_Communication"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: CONSTRAINT "T_Communication_IdCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_IdCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "IdCommunication".';


--
-- Name: CONSTRAINT "T_Communication_DateCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_DateCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "DateCommunication".';


--
-- Name: CONSTRAINT "T_Communication_ValideCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_ValideCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "ValideCommunication".';


--
-- Name: CONSTRAINT "T_Communication_LectureCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_LectureCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "LectureCommunication".';


--
-- Name: T_Communication_IdCommunication_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Communication" ALTER COLUMN "IdCommunication" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Communication_IdCommunication_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Communication_IdCommunication_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Communication_IdCommunication_seq" IS 'Séquence de génération de "communication"."T_Communication"."IdCommunication". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Discussion; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Discussion" (
    "IdDiscussion" integer CONSTRAINT "T_Discussion_IdDiscussion_not_null" NOT NULL,
    "IdUserClientFk" integer,
    "IdProfessionnelFk" integer,
    "IdEntiteFk" integer,
    "TypeDiscussion" character varying(30) CONSTRAINT "T_Discussion_TypeDiscussion_not_null" NOT NULL,
    "SujetDiscussion" character varying(255),
    "DateCreation" timestamp with time zone DEFAULT now() CONSTRAINT "T_Discussion_DateCreation_not_null" NOT NULL,
    "DernierMessageAt" timestamp with time zone,
    "ValideDiscussion" boolean DEFAULT true CONSTRAINT "T_Discussion_ValideDiscussion_not_null" NOT NULL,
    CONSTRAINT "Ck_Discussion_Target" CHECK ((((("TypeDiscussion")::text = 'expert'::text) AND ("IdProfessionnelFk" IS NOT NULL) AND ("IdEntiteFk" IS NULL)) OR ((("TypeDiscussion")::text = 'structure'::text) AND ("IdEntiteFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NULL)))),
    CONSTRAINT "Ck_Discussion_Type" CHECK ((("TypeDiscussion")::text = ANY (ARRAY[('expert'::character varying)::text, ('structure'::character varying)::text])))
);


--
-- Name: TABLE "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Discussion" IS 'Fil de discussion d’un utilisateur avec un professionnel ou une structure. Les contraintes limitent TypeDiscussion à expert/structure et imposent la cible correspondante.';


--
-- Name: COLUMN "T_Discussion"."IdDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdDiscussion" IS 'Identifiant du fil de discussion.';


--
-- Name: COLUMN "T_Discussion"."IdUserClientFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdUserClientFk" IS 'Utilisateur client à l’origine du fil de discussion. Relation imposée : FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Discussion"."IdProfessionnelFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdProfessionnelFk" IS 'Professionnel rattaché à la discussion ou à l’entité. Relation imposée : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Discussion"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Discussion"."TypeDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."TypeDiscussion" IS 'Type de cible du fil : expert ou structure selon la contrainte installée.';


--
-- Name: COLUMN "T_Discussion"."SujetDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."SujetDiscussion" IS 'Sujet ou titre du fil de discussion.';


--
-- Name: COLUMN "T_Discussion"."DateCreation"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."DateCreation" IS 'Horodatage de création de la discussion avec fuseau horaire.';


--
-- Name: COLUMN "T_Discussion"."DernierMessageAt"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."DernierMessageAt" IS 'Horodatage du dernier message associé à la discussion.';


--
-- Name: COLUMN "T_Discussion"."ValideDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."ValideDiscussion" IS 'Indique si la discussion est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: CONSTRAINT "T_Discussion_IdDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_IdDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "IdDiscussion".';


--
-- Name: CONSTRAINT "T_Discussion_TypeDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_TypeDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "TypeDiscussion".';


--
-- Name: CONSTRAINT "T_Discussion_DateCreation_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_DateCreation_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "DateCreation".';


--
-- Name: CONSTRAINT "T_Discussion_ValideDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_ValideDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "ValideDiscussion".';


--
-- Name: CONSTRAINT "Ck_Discussion_Target" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Discussion_Target" ON communication."T_Discussion" IS 'Contrôle de cohérence des valeurs autorisées dans "communication"."T_Discussion". Définition : CHECK ("TypeDiscussion"::text = ''expert''::text AND "IdProfessionnelFk" IS NOT NULL AND "IdEntiteFk" IS NULL OR "TypeDiscussion"::text = ''structure''::text AND "IdEntiteFk" IS NOT NULL AND "IdProfessionnelFk" IS NULL).';


--
-- Name: CONSTRAINT "Ck_Discussion_Type" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Discussion_Type" ON communication."T_Discussion" IS 'Contrôle de cohérence des valeurs autorisées dans "communication"."T_Discussion". Définition : CHECK ("TypeDiscussion"::text = ANY (ARRAY[''expert''::character varying::text, ''structure''::character varying::text])).';


--
-- Name: T_Discussion_IdDiscussion_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Discussion" ALTER COLUMN "IdDiscussion" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Discussion_IdDiscussion_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Discussion_IdDiscussion_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Discussion_IdDiscussion_seq" IS 'Séquence de génération de "communication"."T_Discussion"."IdDiscussion". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Entite; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Entite" (
    "IdEntite" integer CONSTRAINT "T_Entite_IdEntite_not_null" NOT NULL,
    "NomEntite" text CONSTRAINT "T_Entite_NomEntite_not_null" NOT NULL,
    "PhoneEntite" character varying(20),
    "EmailEntite" character varying(255) CONSTRAINT "T_Entite_EmailEntite_not_null" NOT NULL,
    "AdresseEntite" text,
    "DateCreationEntite" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "IdTypeEntiteFk" integer,
    "ValideEntite" boolean DEFAULT true
);


--
-- Name: TABLE "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Entite" IS 'Organisations et structures : identité, coordonnées, type, date de création et validité. Source des rattachements utilisateurs, professionnels, licences et opérations.';


--
-- Name: COLUMN "T_Entite"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."IdEntite" IS 'Identifiant de l’entité.';


--
-- Name: COLUMN "T_Entite"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."NomEntite" IS 'Nom de la structure ou organisation.';


--
-- Name: COLUMN "T_Entite"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."PhoneEntite" IS 'Téléphone de contact de l’entité.';


--
-- Name: COLUMN "T_Entite"."EmailEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."EmailEntite" IS 'Adresse électronique de contact de l’entité.';


--
-- Name: COLUMN "T_Entite"."AdresseEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."AdresseEntite" IS 'Adresse générale enregistrée pour l’entité.';


--
-- Name: COLUMN "T_Entite"."DateCreationEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."DateCreationEntite" IS 'Date et heure de création de l’entité.';


--
-- Name: COLUMN "T_Entite"."IdTypeEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."IdTypeEntiteFk" IS 'Type de structure ou d’organisation dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeEntiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Entite"."ValideEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."ValideEntite" IS 'Indique si l’entité est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: CONSTRAINT "T_Entite_IdEntite_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_IdEntite_not_null" ON systeme."T_Entite" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite". Définition : NOT NULL "IdEntite".';


--
-- Name: CONSTRAINT "T_Entite_NomEntite_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_NomEntite_not_null" ON systeme."T_Entite" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite". Définition : NOT NULL "NomEntite".';


--
-- Name: CONSTRAINT "T_Entite_EmailEntite_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_EmailEntite_not_null" ON systeme."T_Entite" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite". Définition : NOT NULL "EmailEntite".';


--
-- Name: T_Utilisateurs; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Utilisateurs" (
    "IdUser" integer CONSTRAINT "T_Utilisateurs_IdUser_not_null" NOT NULL,
    "NomUser" character varying(100) CONSTRAINT "T_Utilisateurs_NomUser_not_null" NOT NULL,
    "PrenomUser" character varying(100) CONSTRAINT "T_Utilisateurs_PrenomUser_not_null" NOT NULL,
    "EmailUser" character varying(150) CONSTRAINT "T_Utilisateurs_EmailUser_not_null" NOT NULL,
    "MotdepasseUser" text CONSTRAINT "T_Utilisateurs_MotdepasseUser_not_null" NOT NULL,
    "PhoneUser" character varying(20),
    "DatecreationUser" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "IdRoleFk" integer,
    "ValideUser" boolean DEFAULT true CONSTRAINT "T_Utilisateurs_ValideUser_not_null" NOT NULL,
    "SexeUser" character(1) CONSTRAINT "T_Utilisateurs_SexeUser_not_null" NOT NULL,
    "DateModificationUser" timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Utilisateurs_DateModificationUser_not_null" NOT NULL,
    "UrlPhoto" text,
    "IdEntiteFk" integer,
    "Is_staff" boolean DEFAULT false CONSTRAINT "T_Utilisateurs_Is_staff_not_null" NOT NULL,
    "Is_Admin" boolean DEFAULT false CONSTRAINT "T_Utilisateurs_Is_Admin_not_null" NOT NULL,
    CONSTRAINT chk_sexe_utilisateur CHECK (("SexeUser" = ANY (ARRAY['M'::bpchar, 'F'::bpchar])))
);


--
-- Name: TABLE "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Utilisateurs" IS 'Comptes utilisateurs : identité, authentification, rôle, entité, validité et indicateurs staff/administrateur. Les triggers normalisent le téléphone, datent les modifications et alimentent l’audit.';


--
-- Name: COLUMN "T_Utilisateurs"."IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."IdUser" IS 'Identifiant du compte utilisateur.';


--
-- Name: COLUMN "T_Utilisateurs"."NomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."NomUser" IS 'Nom de l’utilisateur.';


--
-- Name: COLUMN "T_Utilisateurs"."PrenomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."PrenomUser" IS 'Prénom de l’utilisateur.';


--
-- Name: COLUMN "T_Utilisateurs"."EmailUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';


--
-- Name: COLUMN "T_Utilisateurs"."MotdepasseUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."MotdepasseUser" IS 'Empreinte du mot de passe utilisée pour l’authentification du compte ; donnée confidentielle à exclure des projections publiques.';


--
-- Name: COLUMN "T_Utilisateurs"."PhoneUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."PhoneUser" IS 'Téléphone utilisateur ; le trigger de normalisation conserve les chiffres sans interpréter le pays.';


--
-- Name: COLUMN "T_Utilisateurs"."DatecreationUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."DatecreationUser" IS 'Date et heure de création du compte.';


--
-- Name: COLUMN "T_Utilisateurs"."IdRoleFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."IdRoleFk" IS 'Rôle de l’utilisateur dans le référentiel. Relation imposée : FOREIGN KEY ("IdRoleFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Utilisateurs"."ValideUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."ValideUser" IS 'Indique si le compte est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Utilisateurs"."SexeUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."SexeUser" IS 'Code de sexe enregistré pour le compte ; la contrainte actuelle admet M ou F.';


--
-- Name: COLUMN "T_Utilisateurs"."DateModificationUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."DateModificationUser" IS 'Date et heure de dernière modification du compte, actualisée par trigger.';


--
-- Name: COLUMN "T_Utilisateurs"."UrlPhoto"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."UrlPhoto" IS 'Référence de la photo de l’utilisateur.';


--
-- Name: COLUMN "T_Utilisateurs"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Utilisateurs"."Is_staff"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."Is_staff" IS 'Indicateur de compte staff ; pris en compte par les contrôles actuels d’administration.';


--
-- Name: COLUMN "T_Utilisateurs"."Is_Admin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."Is_Admin" IS 'Indicateur de compte administrateur ; pris en compte par les contrôles actuels d’administration.';


--
-- Name: CONSTRAINT "T_Utilisateurs_IdUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_IdUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "IdUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_NomUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_NomUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "NomUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_PrenomUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_PrenomUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "PrenomUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_EmailUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_EmailUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "EmailUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_MotdepasseUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_MotdepasseUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "MotdepasseUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_ValideUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_ValideUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "ValideUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_SexeUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_SexeUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "SexeUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_DateModificationUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_DateModificationUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "DateModificationUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_Is_staff_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_Is_staff_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "Is_staff".';


--
-- Name: CONSTRAINT "T_Utilisateurs_Is_Admin_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_Is_Admin_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "Is_Admin".';


--
-- Name: CONSTRAINT chk_sexe_utilisateur ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT chk_sexe_utilisateur ON systeme."T_Utilisateurs" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Utilisateurs". Définition : CHECK ("SexeUser" = ANY (ARRAY[''M''::bpchar, ''F''::bpchar])).';


--
-- Name: V_Chat; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Chat" AS
 SELECT c."IdChat",
    c."TextChat",
    c."ChatFile",
    c."ChatLink",
    c."AuthorIdFk" AS "IdUser",
    c."IdDiscussionFk",
    c."DateChat",
    c."LuChat",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    e."IdEntite",
    e."NomEntite"
   FROM ((communication."T_Chat" c
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = c."AuthorIdFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = u."IdEntiteFk")));


--
-- Name: VIEW "V_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Chat" IS 'Messages au grain message avec discussion et auteur. Vue privée ; le backend doit contrôler les participants avant toute lecture.';


--
-- Name: COLUMN "V_Chat"."IdChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."IdChat" IS 'Identifiant du message.';


--
-- Name: COLUMN "V_Chat"."TextChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."TextChat" IS 'Texte du message de discussion.';


--
-- Name: COLUMN "V_Chat"."ChatFile"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."ChatFile" IS 'Référence de la pièce jointe au message.';


--
-- Name: COLUMN "V_Chat"."ChatLink"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."ChatLink" IS 'Lien associé au message.';


--
-- Name: COLUMN "V_Chat"."IdUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."IdUser" IS 'Identifiant du compte utilisateur.';


--
-- Name: COLUMN "V_Chat"."IdDiscussionFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."IdDiscussionFk" IS 'Discussion contenant le message. Relation imposée : FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: COLUMN "V_Chat"."DateChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."DateChat" IS 'Date et heure du message avec fuseau horaire.';


--
-- Name: COLUMN "V_Chat"."LuChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."LuChat" IS 'Indicateur de lecture enregistré sur le message.';


--
-- Name: COLUMN "V_Chat"."NomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."NomUser" IS 'Nom de l’utilisateur.';


--
-- Name: COLUMN "V_Chat"."PrenomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."PrenomUser" IS 'Prénom de l’utilisateur.';


--
-- Name: COLUMN "V_Chat"."EmailUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';


--
-- Name: COLUMN "V_Chat"."IdEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."IdEntite" IS 'Identifiant de l’entité.';


--
-- Name: COLUMN "V_Chat"."NomEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."NomEntite" IS 'Nom de la structure ou organisation.';


--
-- Name: T_Generique; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_Generique" (
    "ID_Generique" integer CONSTRAINT "T_Generique_ID_Generique_not_null" NOT NULL,
    "ID_CategorieGeneriqueFk" integer CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" NOT NULL,
    "NomGenerique" character varying(255) CONSTRAINT "T_Generique_NomGenerique_not_null" NOT NULL,
    "AbrGenerique" character varying(255),
    "VisibleNiveau_2" boolean DEFAULT true,
    "VisibleNiveau_3" boolean DEFAULT true,
    "VisibleNiveau_4" boolean DEFAULT true,
    "VisibleNiveau_5" boolean DEFAULT true,
    "VisibleArticle" boolean DEFAULT true,
    "VisibleCmd" boolean DEFAULT true,
    "VisibleFacture" boolean DEFAULT true,
    "VisibleUsers" boolean DEFAULT true,
    "VisibleVoie" boolean DEFAULT true,
    "VisibleAll" boolean DEFAULT true,
    "ObsGenerique" text,
    "ValideGenerique" boolean DEFAULT true CONSTRAINT "T_Generique_ValideGenerique_not_null" NOT NULL
);


--
-- Name: TABLE "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_Generique" IS 'Valeurs des nomenclatures rattachées à une catégorie : libellé, abréviation, visibilité par usage et validité. La signification métier dépend de la catégorie.';


--
-- Name: COLUMN "T_Generique"."ID_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ID_Generique" IS 'Identifiant d’une valeur de nomenclature.';


--
-- Name: COLUMN "T_Generique"."ID_CategorieGeneriqueFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ID_CategorieGeneriqueFk" IS 'Catégorie à laquelle appartient cette valeur de nomenclature. Relation imposée : FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Generique"."NomGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."NomGenerique" IS 'Libellé métier de la valeur de nomenclature.';


--
-- Name: COLUMN "T_Generique"."AbrGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."AbrGenerique" IS 'Abréviation de la valeur de nomenclature ; peut porter un code de type utilisé par les règles métier.';


--
-- Name: COLUMN "T_Generique"."VisibleNiveau_2"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_2" IS 'Indicateur de visibilité pour le niveau géographique de niveau 2.';


--
-- Name: COLUMN "T_Generique"."VisibleNiveau_3"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_3" IS 'Indicateur de visibilité pour le niveau géographique de niveau 3.';


--
-- Name: COLUMN "T_Generique"."VisibleNiveau_4"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_4" IS 'Indicateur de visibilité pour le niveau géographique de niveau 4.';


--
-- Name: COLUMN "T_Generique"."VisibleNiveau_5"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5.';


--
-- Name: COLUMN "T_Generique"."VisibleArticle"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleArticle" IS 'Indique la visibilité de la valeur de nomenclature pour les articles.';


--
-- Name: COLUMN "T_Generique"."VisibleCmd"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleCmd" IS 'Indique la visibilité de la valeur de nomenclature pour les commandes.';


--
-- Name: COLUMN "T_Generique"."VisibleFacture"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleFacture" IS 'Indique la visibilité de la valeur de nomenclature pour les factures.';


--
-- Name: COLUMN "T_Generique"."VisibleUsers"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleUsers" IS 'Indique la visibilité de la valeur de nomenclature pour les utilisateurs.';


--
-- Name: COLUMN "T_Generique"."VisibleVoie"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleVoie" IS 'Indique la visibilité de la valeur de nomenclature pour les voies d’accès.';


--
-- Name: COLUMN "T_Generique"."VisibleAll"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleAll" IS 'Indique la visibilité générale de la valeur de nomenclature.';


--
-- Name: COLUMN "T_Generique"."ObsGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ObsGenerique" IS 'Observations enregistrées sur la valeur de nomenclature.';


--
-- Name: COLUMN "T_Generique"."ValideGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ValideGenerique" IS 'Indique si la valeur de nomenclature est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: CONSTRAINT "T_Generique_ID_Generique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ID_Generique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ID_Generique".';


--
-- Name: CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ID_CategorieGeneriqueFk".';


--
-- Name: CONSTRAINT "T_Generique_NomGenerique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_NomGenerique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "NomGenerique".';


--
-- Name: CONSTRAINT "T_Generique_ValideGenerique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ValideGenerique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ValideGenerique".';


--
-- Name: V_Communication; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Communication" AS
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
   FROM (((communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = com."IdUserFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = com."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tg ON ((tg."ID_Generique" = com."IdTypeCommunication")));


--
-- Name: VIEW "V_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Communication" IS 'Notifications au grain communication avec destinataire et entité ; aucune ouverture publique.';


--
-- Name: COLUMN "V_Communication"."IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdCommunication" IS 'Identifiant de la communication ou notification.';


--
-- Name: COLUMN "V_Communication"."DateCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."DateCommunication" IS 'Date et heure d’enregistrement de la communication.';


--
-- Name: COLUMN "V_Communication"."ContenuCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."ContenuCommunication" IS 'Texte de la communication ou notification destinée à l’utilisateur.';


--
-- Name: COLUMN "V_Communication"."ObsCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."ObsCommunication" IS 'Observations enregistrées sur la communication.';


--
-- Name: COLUMN "V_Communication"."ValideCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."ValideCommunication" IS 'Indique si la communication est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "V_Communication"."LectureCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."LectureCommunication" IS 'Indique si la communication est marquée comme lue.';


--
-- Name: COLUMN "V_Communication"."IdUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdUser" IS 'Identifiant du compte utilisateur.';


--
-- Name: COLUMN "V_Communication"."NomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."NomUser" IS 'Nom de l’utilisateur.';


--
-- Name: COLUMN "V_Communication"."PrenomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."PrenomUser" IS 'Prénom de l’utilisateur.';


--
-- Name: COLUMN "V_Communication"."EmailUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';


--
-- Name: COLUMN "V_Communication"."IdEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdEntite" IS 'Identifiant de l’entité.';


--
-- Name: COLUMN "V_Communication"."NomEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."NomEntite" IS 'Nom de la structure ou organisation.';


--
-- Name: COLUMN "V_Communication"."IdTypeCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdTypeCommunication" IS 'Type de communication dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "V_Communication"."TypeCommunicationAbr"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."TypeCommunicationAbr" IS 'Projection SQL de TypeCommunicationAbr ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Communication"."TypeCommunicationLibelle"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."TypeCommunicationLibelle" IS 'Projection SQL de TypeCommunicationLibelle ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: V_Communication_non_lues; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Communication_non_lues" AS
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
   FROM (((communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = com."IdUserFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = com."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tg ON ((tg."ID_Generique" = com."IdTypeCommunication")))
  WHERE ((com."LectureCommunication" = false) AND (com."ValideCommunication" = true));


--
-- Name: VIEW "V_Communication_non_lues"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Communication_non_lues" IS 'Notifications actives et non lues, même grain que V_Communication ; filtrage du destinataire requis.';


--
-- Name: COLUMN "V_Communication_non_lues"."IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdCommunication" IS 'Identifiant de la communication ou notification.';


--
-- Name: COLUMN "V_Communication_non_lues"."DateCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."DateCommunication" IS 'Date et heure d’enregistrement de la communication.';


--
-- Name: COLUMN "V_Communication_non_lues"."ContenuCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."ContenuCommunication" IS 'Texte de la communication ou notification destinée à l’utilisateur.';


--
-- Name: COLUMN "V_Communication_non_lues"."ObsCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."ObsCommunication" IS 'Observations enregistrées sur la communication.';


--
-- Name: COLUMN "V_Communication_non_lues"."ValideCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."ValideCommunication" IS 'Indique si la communication est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "V_Communication_non_lues"."LectureCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."LectureCommunication" IS 'Indique si la communication est marquée comme lue.';


--
-- Name: COLUMN "V_Communication_non_lues"."IdUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdUser" IS 'Identifiant du compte utilisateur.';


--
-- Name: COLUMN "V_Communication_non_lues"."NomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."NomUser" IS 'Nom de l’utilisateur.';


--
-- Name: COLUMN "V_Communication_non_lues"."PrenomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."PrenomUser" IS 'Prénom de l’utilisateur.';


--
-- Name: COLUMN "V_Communication_non_lues"."EmailUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';


--
-- Name: COLUMN "V_Communication_non_lues"."IdEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdEntite" IS 'Identifiant de l’entité.';


--
-- Name: COLUMN "V_Communication_non_lues"."NomEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."NomEntite" IS 'Nom de la structure ou organisation.';


--
-- Name: COLUMN "V_Communication_non_lues"."IdTypeCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdTypeCommunication" IS 'Type de communication dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "V_Communication_non_lues"."TypeCommunicationAbr"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."TypeCommunicationAbr" IS 'Projection SQL de TypeCommunicationAbr ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Communication_non_lues"."TypeCommunicationLibelle"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."TypeCommunicationLibelle" IS 'Projection SQL de TypeCommunicationLibelle ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: T_Niveau_0; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_0" (
    "ID_Niveau_0" integer CONSTRAINT "T_Niveau_0_ID_Niveau_0_not_null" NOT NULL,
    "NomNiveau_0" character varying(255),
    "CodeNiveau_0" character varying(10),
    "geometryNiveau_0" text
);


--
-- Name: TABLE "T_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_0" IS 'Unités géographiques de niveau 0 : identité et géométrie textuelle. Niveau racine de la hiérarchie.';


--
-- Name: COLUMN "T_Niveau_0"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_0"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0.';


--
-- Name: COLUMN "T_Niveau_0"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_0"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0.';


--
-- Name: COLUMN "T_Niveau_0"."CodeNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_0"."CodeNiveau_0" IS 'Code de référence de l’unité géographique de niveau 0.';


--
-- Name: COLUMN "T_Niveau_0"."geometryNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_0"."geometryNiveau_0" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 0.';


--
-- Name: CONSTRAINT "T_Niveau_0_ID_Niveau_0_not_null" ON "T_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_0_ID_Niveau_0_not_null" ON geolocalisation."T_Niveau_0" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_0". Définition : NOT NULL "ID_Niveau_0".';


--
-- Name: T_Niveau_0_ID_Niveau_0_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_0" ALTER COLUMN "ID_Niveau_0" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_0_ID_Niveau_0_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Niveau_0_ID_Niveau_0_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_0_ID_Niveau_0_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_0"."ID_Niveau_0". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Niveau_1; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_1" (
    "ID_Niveau_1" integer CONSTRAINT "T_Niveau_1_ID_Niveau_1_not_null" NOT NULL,
    "ID_Niveau_0_Fk" integer,
    "ID_Niveau_1_Old_Fk" integer,
    "NomNiveau_1" character varying(255),
    "Alt1_Niveau_1" character varying(255),
    "Alt2_Niveau_1" character varying(255),
    "AbreNiveau_1" character varying(255),
    "CodeSNIS" character varying(255),
    "CodeNiveau_1" character varying(255),
    "PopulationNiveau_1" numeric(12,0),
    "geometryNiveau_1" text,
    "surfaceNiveau_1" character varying(255),
    "timezoneNiveau_1" character varying(255),
    "wikidataNiveau_1" text,
    "EtenduNiveau_1" text,
    "ObsNiveau_1" text,
    "FusionNiveau_1" boolean,
    "VisibleNiveau_1" boolean DEFAULT true CONSTRAINT "T_Niveau_1_VisibleNiveau_1_not_null" NOT NULL,
    "VisibleNiveau_5" boolean DEFAULT true CONSTRAINT "T_Niveau_1_VisibleNiveau_5_not_null" NOT NULL,
    "LatitudeNiveau_1" numeric(9,6),
    "LongitudeNiveau_1" numeric(9,6)
);


--
-- Name: TABLE "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_1" IS 'Unités géographiques de niveau 1 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';


--
-- Name: COLUMN "T_Niveau_1"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."ID_Niveau_0_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."ID_Niveau_0_Fk" IS 'Unité géographique de rattachement de niveau 0. Relation imposée : FOREIGN KEY ("ID_Niveau_0_Fk") REFERENCES geolocalisation."T_Niveau_0"("ID_Niveau_0") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_1"."ID_Niveau_1_Old_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."ID_Niveau_1_Old_Fk" IS 'Unité géographique de rattachement de niveau 1_Old. Relation imposée : FOREIGN KEY ("ID_Niveau_1_Old_Fk") REFERENCES geolocalisation."T_Niveau_1_Old"("ID_Niveau_1_Old") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_1"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."Alt1_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."Alt1_Niveau_1" IS 'Première appellation alternative de l’unité de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."Alt2_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."Alt2_Niveau_1" IS 'Deuxième appellation alternative de l’unité de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."AbreNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."AbreNiveau_1" IS 'Abréviation de l’unité géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."CodeSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."CodeSNIS" IS 'Code SNIS enregistré pour l’unité géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."CodeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."CodeNiveau_1" IS 'Code de référence de l’unité géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."PopulationNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."PopulationNiveau_1" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."geometryNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."geometryNiveau_1" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."surfaceNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."surfaceNiveau_1" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."timezoneNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."timezoneNiveau_1" IS 'Fuseau horaire déclaré pour l’unité de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."wikidataNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."wikidataNiveau_1" IS 'Référence Wikidata déclarée pour l’unité de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."EtenduNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."EtenduNiveau_1" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."ObsNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."ObsNiveau_1" IS 'Observations sur l’unité géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."FusionNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."FusionNiveau_1" IS 'Indicateur de fusion enregistré pour l’unité de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."VisibleNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."VisibleNiveau_1" IS 'Indicateur de visibilité pour le niveau géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."VisibleNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_1"."LatitudeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."LatitudeNiveau_1" IS 'Latitude enregistrée pour l’unité géographique de niveau 1.';


--
-- Name: COLUMN "T_Niveau_1"."LongitudeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1"."LongitudeNiveau_1" IS 'Longitude enregistrée pour l’unité géographique de niveau 1.';


--
-- Name: CONSTRAINT "T_Niveau_1_ID_Niveau_1_not_null" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_ID_Niveau_1_not_null" ON geolocalisation."T_Niveau_1" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_1". Définition : NOT NULL "ID_Niveau_1".';


--
-- Name: CONSTRAINT "T_Niveau_1_VisibleNiveau_1_not_null" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_VisibleNiveau_1_not_null" ON geolocalisation."T_Niveau_1" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_1". Définition : NOT NULL "VisibleNiveau_1".';


--
-- Name: CONSTRAINT "T_Niveau_1_VisibleNiveau_5_not_null" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_VisibleNiveau_5_not_null" ON geolocalisation."T_Niveau_1" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_1". Définition : NOT NULL "VisibleNiveau_5".';


--
-- Name: T_Niveau_1_ID_Niveau_1_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_1" ALTER COLUMN "ID_Niveau_1" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_1_ID_Niveau_1_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Niveau_1_ID_Niveau_1_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_1_ID_Niveau_1_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_1"."ID_Niveau_1". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Niveau_1_Old; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_1_Old" (
    "ID_Niveau_1_Old" integer CONSTRAINT "T_Niveau_1_Old_ID_Niveau_1_Old_not_null" NOT NULL,
    "NomNiveau_1_Old" character varying(255),
    "geometryNiveau_1_Old" text,
    "surfaceNiveau_1_Old" character varying(255)
);


--
-- Name: TABLE "T_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_1_Old" IS 'Anciennes unités géographiques de niveau 1, conservées pour les correspondances historiques avec le découpage courant.';


--
-- Name: COLUMN "T_Niveau_1_Old"."ID_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1_Old"."ID_Niveau_1_Old" IS 'Identifiant de l’unité géographique de niveau 1 historique.';


--
-- Name: COLUMN "T_Niveau_1_Old"."NomNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1_Old"."NomNiveau_1_Old" IS 'Nom de l’unité géographique de niveau 1 historique.';


--
-- Name: COLUMN "T_Niveau_1_Old"."geometryNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1_Old"."geometryNiveau_1_Old" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 1 historique.';


--
-- Name: COLUMN "T_Niveau_1_Old"."surfaceNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_1_Old"."surfaceNiveau_1_Old" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 1 historique.';


--
-- Name: CONSTRAINT "T_Niveau_1_Old_ID_Niveau_1_Old_not_null" ON "T_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_Old_ID_Niveau_1_Old_not_null" ON geolocalisation."T_Niveau_1_Old" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_1_Old". Définition : NOT NULL "ID_Niveau_1_Old".';


--
-- Name: T_Niveau_1_Old_ID_Niveau_1_Old_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_1_Old" ALTER COLUMN "ID_Niveau_1_Old" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_1_Old_ID_Niveau_1_Old_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Niveau_1_Old_ID_Niveau_1_Old_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_1_Old_ID_Niveau_1_Old_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_1_Old"."ID_Niveau_1_Old". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Niveau_2; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_2" (
    "ID_Niveau_2" integer CONSTRAINT "T_Niveau_2_ID_Niveau_2_not_null" NOT NULL,
    "ID_Niveau_1_FK" integer,
    "ID_TypeNiveau_2_Fk" integer,
    "NomNiveau_2" character varying(255),
    "Alt1_NomNiveau_2" character varying(255),
    "AbreNiveau_2" character varying(255),
    "CodeNiveau_2" character varying(255),
    "PopulationNiveau_2" numeric(12,0),
    "geometryNiveau_2" text,
    "surfaceNiveau_2" character varying(255),
    "EtenduNiveau_2" text,
    "ObsNiveau_2" text,
    "ID_StatutNiveau_2" integer,
    "ID_StatusDeploiFk" integer,
    "KmDPSANT" numeric(10,2),
    "ID_VoieAccesDPSANTFk" integer,
    "SelectNiveau_2" boolean,
    "LatitudeNiveau_2" numeric(9,6),
    "LongitudeNiveau_2" numeric(9,6),
    "AltitudeNiveau_2" numeric(10,2)
);


--
-- Name: TABLE "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_2" IS 'Unités géographiques de niveau 2 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';


--
-- Name: COLUMN "T_Niveau_2"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."ID_Niveau_1_FK"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_Niveau_1_FK" IS 'Unité géographique de rattachement de niveau 1. Relation imposée : FOREIGN KEY ("ID_Niveau_1_FK") REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_2"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Niveau_2"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."Alt1_NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."Alt1_NomNiveau_2" IS 'Appellation alternative de l’unité de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."AbreNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."AbreNiveau_2" IS 'Abréviation de l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."CodeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."CodeNiveau_2" IS 'Code de référence de l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."PopulationNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."PopulationNiveau_2" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."geometryNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."geometryNiveau_2" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."surfaceNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."surfaceNiveau_2" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."EtenduNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."EtenduNiveau_2" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."ObsNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ObsNiveau_2" IS 'Observations sur l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."ID_StatutNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_StatutNiveau_2" IS 'Statut de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_StatutNiveau_2") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_2"."ID_StatusDeploiFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_StatusDeploiFk" IS 'Statut de déploiement enregistré pour l’unité de niveau 2. Relation imposée : FOREIGN KEY ("ID_StatusDeploiFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_2"."KmDPSANT"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."KmDPSANT" IS 'Distance enregistrée entre la DPS et l’antenne, en kilomètres.';


--
-- Name: COLUMN "T_Niveau_2"."ID_VoieAccesDPSANTFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."ID_VoieAccesDPSANTFk" IS 'Voie d’accès entre la DPS et l’antenne. Relation imposée : FOREIGN KEY ("ID_VoieAccesDPSANTFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_2"."SelectNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."SelectNiveau_2" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."LatitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."LatitudeNiveau_2" IS 'Latitude enregistrée pour l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."LongitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."LongitudeNiveau_2" IS 'Longitude enregistrée pour l’unité géographique de niveau 2.';


--
-- Name: COLUMN "T_Niveau_2"."AltitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_2"."AltitudeNiveau_2" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 2.';


--
-- Name: CONSTRAINT "T_Niveau_2_ID_Niveau_2_not_null" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_2_ID_Niveau_2_not_null" ON geolocalisation."T_Niveau_2" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_2". Définition : NOT NULL "ID_Niveau_2".';


--
-- Name: T_Niveau_2_ID_Niveau_2_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_2" ALTER COLUMN "ID_Niveau_2" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_2_ID_Niveau_2_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Niveau_2_ID_Niveau_2_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_2_ID_Niveau_2_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_2"."ID_Niveau_2". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Niveau_3; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_3" (
    "ID_Niveau_3" integer CONSTRAINT "T_Niveau_3_ID_Niveau_3_not_null" NOT NULL,
    "ID_Niveau_2_FK" integer,
    "ID_TypeNiveau_2_Fk" integer,
    "NomNiveau_3" character varying(255),
    "Alt_Niveau_3" character varying(255),
    "surfaceNiveau_3" character varying(255),
    "geometryNiveau_3" text,
    "AbreNiveau_3" character varying(255),
    "CodeNiveau_3" character varying(255),
    "PopulationNiveau_3" numeric(12,0),
    "EtenduNiveau_3" text,
    "ObsNiveau_3" text,
    "ID_StatutNiveau_3_Fk" integer,
    "ID_StatutDeploieFk" integer,
    "KmAntenneBCZS" numeric(100,7),
    "ID_VoieAccesANTBCZFk" integer,
    "KmDPSBCZS" numeric(100,7),
    "ID_VoieAccesDPSBCZFk" integer,
    "SelectNiveau_3" boolean,
    "LatitudeNiveau_3" numeric(13,5),
    "LongitudeNiveau_3" numeric(13,5),
    "AltitudeNiveau_3" numeric(10,7)
);


--
-- Name: TABLE "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_3" IS 'Unités géographiques de niveau 3 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';


--
-- Name: COLUMN "T_Niveau_3"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."ID_Niveau_2_FK"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_Niveau_2_FK" IS 'Unité géographique de rattachement de niveau 2. Relation imposée : FOREIGN KEY ("ID_Niveau_2_FK") REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_3"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE NOT VALID.';


--
-- Name: COLUMN "T_Niveau_3"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."Alt_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."Alt_Niveau_3" IS 'Appellation alternative de l’unité de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."surfaceNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."surfaceNiveau_3" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."geometryNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."geometryNiveau_3" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."AbreNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."AbreNiveau_3" IS 'Abréviation de l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."CodeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."CodeNiveau_3" IS 'Code de référence de l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."PopulationNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."PopulationNiveau_3" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."EtenduNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."EtenduNiveau_3" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."ObsNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ObsNiveau_3" IS 'Observations sur l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."ID_StatutNiveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_StatutNiveau_3_Fk" IS 'Statut de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_StatutNiveau_3_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_3"."ID_StatutDeploieFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_StatutDeploieFk" IS 'Statut de déploiement enregistré pour l’unité de niveau 3. Relation imposée : FOREIGN KEY ("ID_StatutDeploieFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_3"."KmAntenneBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."KmAntenneBCZS" IS 'Distance enregistrée entre l’antenne et le bureau central de zone de santé, en kilomètres.';


--
-- Name: COLUMN "T_Niveau_3"."ID_VoieAccesANTBCZFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_VoieAccesANTBCZFk" IS 'Voie d’accès entre l’antenne et le bureau central de zone de santé. Relation imposée : FOREIGN KEY ("ID_VoieAccesANTBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_3"."KmDPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."KmDPSBCZS" IS 'Distance enregistrée entre la DPS et le bureau central de zone de santé, en kilomètres.';


--
-- Name: COLUMN "T_Niveau_3"."ID_VoieAccesDPSBCZFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."ID_VoieAccesDPSBCZFk" IS 'Voie d’accès entre la DPS et le bureau central de zone de santé. Relation imposée : FOREIGN KEY ("ID_VoieAccesDPSBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_3"."SelectNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."SelectNiveau_3" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."LatitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."LatitudeNiveau_3" IS 'Latitude enregistrée pour l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."LongitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."LongitudeNiveau_3" IS 'Longitude enregistrée pour l’unité géographique de niveau 3.';


--
-- Name: COLUMN "T_Niveau_3"."AltitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_3"."AltitudeNiveau_3" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 3.';


--
-- Name: CONSTRAINT "T_Niveau_3_ID_Niveau_3_not_null" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_3_ID_Niveau_3_not_null" ON geolocalisation."T_Niveau_3" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_3". Définition : NOT NULL "ID_Niveau_3".';


--
-- Name: T_Niveau_3_ID_Niveau_3_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_3" ALTER COLUMN "ID_Niveau_3" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_3_ID_Niveau_3_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Niveau_3_ID_Niveau_3_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_3_ID_Niveau_3_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_3"."ID_Niveau_3". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Niveau_4; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_4" (
    "ID_Niveau_4" integer CONSTRAINT "T_Niveau_4_ID_Niveau_4_not_null" NOT NULL,
    "ID_Niveau_3_Fk" integer,
    "ID_TypeNiveau_4_Fk" integer,
    "NomNiveau_4" character varying(255),
    "AbreNiveau_4" character varying(255),
    "CodeNiveau_4" character varying(255),
    "surfaceNiveau_4" character varying(255),
    "geometryNiveau_4" text,
    "ID_DispoReseauNiveau_4" integer,
    "ID_VoieAccesZsASFk" integer,
    "ID_StatutNiveau_4" integer,
    "ID_StatutDeploiementFk" integer,
    "ObsNiveau_4" text,
    "SelectNiveau_4" boolean,
    "LatitudeNiveau_4" numeric(13,6),
    "LongitudeNiveau_4" numeric(13,6),
    "AltitudeNiveau_4" numeric(10,2),
    "PopulationNiveau_4" numeric(12,0),
    "KmZoneSanteAS" numeric(10,2)
);


--
-- Name: TABLE "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_4" IS 'Unités géographiques de niveau 4 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';


--
-- Name: COLUMN "T_Niveau_4"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_Niveau_4" IS 'Identifiant de l’unité géographique de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_Niveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Relation imposée : FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_4"."ID_TypeNiveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_TypeNiveau_4_Fk" IS 'Type de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_TypeNiveau_4_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE NOT VALID.';


--
-- Name: COLUMN "T_Niveau_4"."NomNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."NomNiveau_4" IS 'Nom de l’unité géographique de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."AbreNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."AbreNiveau_4" IS 'Abréviation de l’unité géographique de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."CodeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."CodeNiveau_4" IS 'Code de référence de l’unité géographique de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."surfaceNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."surfaceNiveau_4" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."geometryNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."geometryNiveau_4" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."ID_DispoReseauNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_DispoReseauNiveau_4" IS 'Disponibilité du réseau déclarée pour l’unité géographique, dans le référentiel. Relation imposée : FOREIGN KEY ("ID_DispoReseauNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_4"."ID_VoieAccesZsASFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_VoieAccesZsASFk" IS 'Voie d’accès entre la zone de santé et l’aire de santé. Relation imposée : FOREIGN KEY ("ID_VoieAccesZsASFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_4"."ID_StatutNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_StatutNiveau_4" IS 'Statut de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_StatutNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_4"."ID_StatutDeploiementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ID_StatutDeploiementFk" IS 'Statut de déploiement enregistré pour l’unité géographique. Relation imposée : FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_4"."ObsNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."ObsNiveau_4" IS 'Observations sur l’unité géographique de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."SelectNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."SelectNiveau_4" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."LatitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."LatitudeNiveau_4" IS 'Latitude enregistrée pour l’unité géographique de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."LongitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."LongitudeNiveau_4" IS 'Longitude enregistrée pour l’unité géographique de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."AltitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."AltitudeNiveau_4" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."PopulationNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."PopulationNiveau_4" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 4.';


--
-- Name: COLUMN "T_Niveau_4"."KmZoneSanteAS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_4"."KmZoneSanteAS" IS 'Distance enregistrée entre la zone de santé et l’aire de santé, en kilomètres.';


--
-- Name: CONSTRAINT "T_Niveau_4_ID_Niveau_4_not_null" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_4_ID_Niveau_4_not_null" ON geolocalisation."T_Niveau_4" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_4". Définition : NOT NULL "ID_Niveau_4".';


--
-- Name: T_Niveau_4_ID_Niveau_4_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_4" ALTER COLUMN "ID_Niveau_4" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_4_ID_Niveau_4_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Niveau_4_ID_Niveau_4_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_4_ID_Niveau_4_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_4"."ID_Niveau_4". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Niveau_5; Type: TABLE; Schema: geolocalisation; Owner: -
--

CREATE TABLE geolocalisation."T_Niveau_5" (
    "ID_Niveau_5" integer CONSTRAINT "T_Niveau_5_ID_Niveau_5_not_null" NOT NULL,
    "ID_Niveau_4_Fk" integer,
    "ID_Niveau_3_Fk" integer,
    "ID_TypeNiveau_5_Fk" integer,
    "NomNiveau_5" character varying(255),
    "AbreNiveau_5" character varying(255),
    "CodeNiveau_5" character varying(255),
    "PopulationNiveau_5" numeric(12,0),
    "surfaceNiveau_5" character varying(255),
    "geometryNiveau_5" text,
    "ID_DispoReseauNiveau_5" integer,
    "ID_VoieAccesZsSiteFk" integer,
    "ID_StatutNiveau_5" integer,
    "ID_StatutDeploiementFk" integer,
    "ObsNiveau_5" text,
    "SelectNiveau_5" boolean,
    "ID_TypeToitFk" integer,
    "KmZoneSanteNiveau_5" numeric(12,2),
    "LatitudeNiveau_5" numeric(12,6),
    "LongitudeNiveau_5" numeric(12,6),
    "AltitudeNiveau_5" numeric(12,2)
);


--
-- Name: TABLE "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON TABLE geolocalisation."T_Niveau_5" IS 'Unités géographiques de niveau 5 : identité et géométrie textuelle, rattachements hiérarchiques et attributs territoriaux. Les types, statuts et voies d’accès utilisent les nomenclatures du référentiel.';


--
-- Name: COLUMN "T_Niveau_5"."ID_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_Niveau_5" IS 'Identifiant de l’unité géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."ID_Niveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_Niveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Relation imposée : FOREIGN KEY ("ID_Niveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_5"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_Niveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Relation imposée : FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_5"."ID_TypeNiveau_5_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel.';


--
-- Name: COLUMN "T_Niveau_5"."NomNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."NomNiveau_5" IS 'Nom de l’unité géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."AbreNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."AbreNiveau_5" IS 'Abréviation de l’unité géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."CodeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."CodeNiveau_5" IS 'Code de référence de l’unité géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."PopulationNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."PopulationNiveau_5" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."surfaceNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."surfaceNiveau_5" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."geometryNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."geometryNiveau_5" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."ID_DispoReseauNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_DispoReseauNiveau_5" IS 'Disponibilité du réseau déclarée pour l’unité géographique, dans le référentiel. Relation imposée : FOREIGN KEY ("ID_DispoReseauNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_5"."ID_VoieAccesZsSiteFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_VoieAccesZsSiteFk" IS 'Voie d’accès entre la zone de santé et le site. Relation imposée : FOREIGN KEY ("ID_VoieAccesZsSiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_5"."ID_StatutNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_StatutNiveau_5" IS 'Statut de l’unité géographique dans le référentiel. Relation imposée : FOREIGN KEY ("ID_StatutNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_5"."ID_StatutDeploiementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_StatutDeploiementFk" IS 'Statut de déploiement enregistré pour l’unité géographique. Relation imposée : FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_5"."ObsNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ObsNiveau_5" IS 'Observations sur l’unité géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."SelectNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."SelectNiveau_5" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."ID_TypeToitFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."ID_TypeToitFk" IS 'Type de toiture du site, issu du référentiel. Relation imposée : FOREIGN KEY ("ID_TypeToitFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Niveau_5"."KmZoneSanteNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."KmZoneSanteNiveau_5" IS 'Distance enregistrée entre la zone de santé et le site, en kilomètres.';


--
-- Name: COLUMN "T_Niveau_5"."LatitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."LatitudeNiveau_5" IS 'Latitude enregistrée pour l’unité géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."LongitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."LongitudeNiveau_5" IS 'Longitude enregistrée pour l’unité géographique de niveau 5.';


--
-- Name: COLUMN "T_Niveau_5"."AltitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."T_Niveau_5"."AltitudeNiveau_5" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 5.';


--
-- Name: CONSTRAINT "T_Niveau_5_ID_Niveau_5_not_null" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_5_ID_Niveau_5_not_null" ON geolocalisation."T_Niveau_5" IS 'Non-nullité : exige une valeur renseignée dans "geolocalisation"."T_Niveau_5". Définition : NOT NULL "ID_Niveau_5".';


--
-- Name: T_Niveau_5_ID_Niveau_5_seq; Type: SEQUENCE; Schema: geolocalisation; Owner: -
--

ALTER TABLE geolocalisation."T_Niveau_5" ALTER COLUMN "ID_Niveau_5" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME geolocalisation."T_Niveau_5_ID_Niveau_5_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Niveau_5_ID_Niveau_5_seq"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON SEQUENCE geolocalisation."T_Niveau_5_ID_Niveau_5_seq" IS 'Séquence de génération de "geolocalisation"."T_Niveau_5"."ID_Niveau_5". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: V_AS_sans_Site; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_AS_sans_Site" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_Niveau_4",
    n4."NomNiveau_4"
   FROM (((((geolocalisation."T_Niveau_4" n4
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n4."ID_Niveau_3_Fk" = n3."ID_Niveau_3")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_5" n5 ON ((n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3", n4."ID_Niveau_4", n4."NomNiveau_4"
 HAVING (count(n5."ID_Niveau_5") = 0);


--
-- Name: VIEW "V_AS_sans_Site"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_AS_sans_Site" IS 'Vue de controle qualite : Aires de Sante (Niveau 4) sans structure ou site (Niveau 5).';


--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';


--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';


--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';


--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';


--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';


--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';


--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: COLUMN "V_AS_sans_Site"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."ID_Niveau_4" IS 'Identifiant de l’unité géographique de niveau 4. Expression projetée : n4."ID_Niveau_4".';


--
-- Name: COLUMN "V_AS_sans_Site"."NomNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_AS_sans_Site"."NomNiveau_4" IS 'Nom de l’unité géographique de niveau 4. Expression projetée : n4."NomNiveau_4".';


--
-- Name: V_Niveau_0; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_0" AS
 SELECT "ID_Niveau_0",
    "NomNiveau_0",
    "CodeNiveau_0",
    "geometryNiveau_0"
   FROM geolocalisation."T_Niveau_0" n0;


--
-- Name: VIEW "V_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_0" IS 'Vue de reference du Niveau 0 : nom, code et geometrie.';


--
-- Name: COLUMN "V_Niveau_0"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : "ID_Niveau_0".';


--
-- Name: COLUMN "V_Niveau_0"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : "NomNiveau_0".';


--
-- Name: COLUMN "V_Niveau_0"."CodeNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."CodeNiveau_0" IS 'Code de référence de l’unité géographique de niveau 0. Expression projetée : "CodeNiveau_0".';


--
-- Name: COLUMN "V_Niveau_0"."geometryNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_0"."geometryNiveau_0" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 0. Expression projetée : "geometryNiveau_0".';


--
-- Name: V_Niveau_1; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_1" AS
 SELECT n1a."ID_Niveau_0_Fk",
    n0."NomNiveau_0",
    n1a."ID_Niveau_1_Old_Fk",
    n1b."NomNiveau_1_Old",
    n1a."ID_Niveau_1",
    n1a."NomNiveau_1",
    n1a."Alt1_Niveau_1",
    n1a."Alt2_Niveau_1",
    n1a."AbreNiveau_1",
    n1a."CodeSNIS",
    n1a."CodeNiveau_1",
    n1a."PopulationNiveau_1",
    n1a."LatitudeNiveau_1",
    n1a."LongitudeNiveau_1",
    n1a."surfaceNiveau_1",
    n1a."geometryNiveau_1",
    n1a."EtenduNiveau_1",
    n1a."timezoneNiveau_1",
    n1a."wikidataNiveau_1",
    n1a."FusionNiveau_1",
    n1a."VisibleNiveau_1",
    n1a."VisibleNiveau_5",
    n1a."ObsNiveau_1"
   FROM ((geolocalisation."T_Niveau_1" n1a
     LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON ((n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")));


--
-- Name: VIEW "V_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_1" IS 'Vue de reference du Niveau 1 avec rattachement au Niveau 0 et a l''ancien Niveau 1.';


--
-- Name: COLUMN "V_Niveau_1"."ID_Niveau_0_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."ID_Niveau_0_Fk" IS 'Unité géographique de rattachement de niveau 0. Expression projetée : n1a."ID_Niveau_0_Fk".';


--
-- Name: COLUMN "V_Niveau_1"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_Niveau_1"."ID_Niveau_1_Old_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."ID_Niveau_1_Old_Fk" IS 'Unité géographique de rattachement de niveau 1_Old. Expression projetée : n1a."ID_Niveau_1_Old_Fk".';


--
-- Name: COLUMN "V_Niveau_1"."NomNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."NomNiveau_1_Old" IS 'Nom de l’unité géographique de niveau 1 historique. Expression projetée : n1b."NomNiveau_1_Old".';


--
-- Name: COLUMN "V_Niveau_1"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1a."ID_Niveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1a."NomNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."Alt1_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."Alt1_Niveau_1" IS 'Première appellation alternative de l’unité de niveau 1. Expression projetée : n1a."Alt1_Niveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."Alt2_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."Alt2_Niveau_1" IS 'Deuxième appellation alternative de l’unité de niveau 1. Expression projetée : n1a."Alt2_Niveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."AbreNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."AbreNiveau_1" IS 'Abréviation de l’unité géographique de niveau 1. Expression projetée : n1a."AbreNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."CodeSNIS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."CodeSNIS" IS 'Code SNIS enregistré pour l’unité géographique de niveau 1. Expression projetée : n1a."CodeSNIS".';


--
-- Name: COLUMN "V_Niveau_1"."CodeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."CodeNiveau_1" IS 'Code de référence de l’unité géographique de niveau 1. Expression projetée : n1a."CodeNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."PopulationNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."PopulationNiveau_1" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 1. Expression projetée : n1a."PopulationNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."LatitudeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."LatitudeNiveau_1" IS 'Latitude enregistrée pour l’unité géographique de niveau 1. Expression projetée : n1a."LatitudeNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."LongitudeNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."LongitudeNiveau_1" IS 'Longitude enregistrée pour l’unité géographique de niveau 1. Expression projetée : n1a."LongitudeNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."surfaceNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."surfaceNiveau_1" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 1. Expression projetée : n1a."surfaceNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."geometryNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."geometryNiveau_1" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 1. Expression projetée : n1a."geometryNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."EtenduNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."EtenduNiveau_1" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 1. Expression projetée : n1a."EtenduNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."timezoneNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."timezoneNiveau_1" IS 'Fuseau horaire déclaré pour l’unité de niveau 1. Expression projetée : n1a."timezoneNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."wikidataNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."wikidataNiveau_1" IS 'Référence Wikidata déclarée pour l’unité de niveau 1. Expression projetée : n1a."wikidataNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."FusionNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."FusionNiveau_1" IS 'Indicateur de fusion enregistré pour l’unité de niveau 1. Expression projetée : n1a."FusionNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."VisibleNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."VisibleNiveau_1" IS 'Indicateur de visibilité pour le niveau géographique de niveau 1. Expression projetée : n1a."VisibleNiveau_1".';


--
-- Name: COLUMN "V_Niveau_1"."VisibleNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5. Expression projetée : n1a."VisibleNiveau_5".';


--
-- Name: COLUMN "V_Niveau_1"."ObsNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1"."ObsNiveau_1" IS 'Observations sur l’unité géographique de niveau 1. Expression projetée : n1a."ObsNiveau_1".';


--
-- Name: V_Niveau_1_Old; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_1_Old" AS
 SELECT "ID_Niveau_1_Old",
    "NomNiveau_1_Old",
    "geometryNiveau_1_Old",
    "surfaceNiveau_1_Old"
   FROM geolocalisation."T_Niveau_1_Old" n1o;


--
-- Name: VIEW "V_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_1_Old" IS 'Vue de reference de l''ancien Niveau 1 pour les correspondances historiques.';


--
-- Name: COLUMN "V_Niveau_1_Old"."ID_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1_Old"."ID_Niveau_1_Old" IS 'Identifiant de l’unité géographique de niveau 1 historique. Expression projetée : "ID_Niveau_1_Old".';


--
-- Name: COLUMN "V_Niveau_1_Old"."NomNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1_Old"."NomNiveau_1_Old" IS 'Nom de l’unité géographique de niveau 1 historique. Expression projetée : "NomNiveau_1_Old".';


--
-- Name: COLUMN "V_Niveau_1_Old"."geometryNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1_Old"."geometryNiveau_1_Old" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 1 historique. Expression projetée : "geometryNiveau_1_Old".';


--
-- Name: COLUMN "V_Niveau_1_Old"."surfaceNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_1_Old"."surfaceNiveau_1_Old" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 1 historique. Expression projetée : "surfaceNiveau_1_Old".';


--
-- Name: V_Niveau_2; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_2" AS
 SELECT n0."NomNiveau_0",
    n1b."NomNiveau_1_Old",
    n2."ID_Niveau_1_FK",
    n1a."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."ID_TypeNiveau_2_Fk",
    COALESCE(g_type."AbrGenerique", ' '::character varying) AS "Type_Niveau_2",
    n2."NomNiveau_2",
    n2."Alt1_NomNiveau_2",
    n2."AbreNiveau_2",
    n2."CodeNiveau_2",
    n2."PopulationNiveau_2",
    n2."LatitudeNiveau_2",
    n2."LongitudeNiveau_2",
    n2."AltitudeNiveau_2",
    n2."geometryNiveau_2",
    n2."surfaceNiveau_2",
    n2."EtenduNiveau_2",
    n2."ObsNiveau_2",
    n2."ID_StatutNiveau_2",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "Statut_Niveau_2",
    n2."ID_StatusDeploiFk",
    COALESCE(g_deploi."AbrGenerique", ' '::character varying) AS "Statut_Deploiement",
    n2."KmDPSANT",
    n2."ID_VoieAccesDPSANTFk",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "Voie_Acces_DPS",
    n2."SelectNiveau_2"
   FROM (((((((geolocalisation."T_Niveau_2" n2
     LEFT JOIN geolocalisation."T_Niveau_1" n1a ON ((n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON ((n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n2."ID_TypeNiveau_2_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n2."ID_StatutNiveau_2" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploi ON ((n2."ID_StatusDeploiFk" = g_deploi."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n2."ID_VoieAccesDPSANTFk" = g_voie."ID_Generique")));


--
-- Name: VIEW "V_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_2" IS 'Vue de reference du Niveau 2 avec contexte hierarchique, type, statut, deploiement et voie d''acces.';


--
-- Name: COLUMN "V_Niveau_2"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_Niveau_2"."NomNiveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."NomNiveau_1_Old" IS 'Nom de l’unité géographique de niveau 1 historique. Expression projetée : n1b."NomNiveau_1_Old".';


--
-- Name: COLUMN "V_Niveau_2"."ID_Niveau_1_FK"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_1_FK" IS 'Unité géographique de rattachement de niveau 1. Expression projetée : n2."ID_Niveau_1_FK".';


--
-- Name: COLUMN "V_Niveau_2"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1a."NomNiveau_1".';


--
-- Name: COLUMN "V_Niveau_2"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n2."ID_TypeNiveau_2_Fk".';


--
-- Name: COLUMN "V_Niveau_2"."Type_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Type_Niveau_2" IS 'Abréviation du type d’unité de niveau 2 dans le référentiel. Expression projetée : COALESCE(g_type."AbrGenerique", '' ''::character varying) AS "Type_Niveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."Alt1_NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Alt1_NomNiveau_2" IS 'Appellation alternative de l’unité de niveau 2. Expression projetée : n2."Alt1_NomNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."AbreNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."AbreNiveau_2" IS 'Abréviation de l’unité géographique de niveau 2. Expression projetée : n2."AbreNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."CodeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."CodeNiveau_2" IS 'Code de référence de l’unité géographique de niveau 2. Expression projetée : n2."CodeNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."PopulationNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."PopulationNiveau_2" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 2. Expression projetée : n2."PopulationNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."LatitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."LatitudeNiveau_2" IS 'Latitude enregistrée pour l’unité géographique de niveau 2. Expression projetée : n2."LatitudeNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."LongitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."LongitudeNiveau_2" IS 'Longitude enregistrée pour l’unité géographique de niveau 2. Expression projetée : n2."LongitudeNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."AltitudeNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."AltitudeNiveau_2" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 2. Expression projetée : n2."AltitudeNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."geometryNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."geometryNiveau_2" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 2. Expression projetée : n2."geometryNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."surfaceNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."surfaceNiveau_2" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 2. Expression projetée : n2."surfaceNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."EtenduNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."EtenduNiveau_2" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 2. Expression projetée : n2."EtenduNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."ObsNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ObsNiveau_2" IS 'Observations sur l’unité géographique de niveau 2. Expression projetée : n2."ObsNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."ID_StatutNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_StatutNiveau_2" IS 'Statut de l’unité géographique dans le référentiel. Expression projetée : n2."ID_StatutNiveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."Statut_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Statut_Niveau_2" IS 'Abréviation du statut de l’unité de niveau 2. Expression projetée : COALESCE(g_statut."AbrGenerique", '' ''::character varying) AS "Statut_Niveau_2".';


--
-- Name: COLUMN "V_Niveau_2"."ID_StatusDeploiFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_StatusDeploiFk" IS 'Statut de déploiement enregistré pour l’unité de niveau 2. Expression projetée : n2."ID_StatusDeploiFk".';


--
-- Name: COLUMN "V_Niveau_2"."Statut_Deploiement"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Statut_Deploiement" IS 'Abréviation du statut de déploiement issu du référentiel. Expression projetée : COALESCE(g_deploi."AbrGenerique", '' ''::character varying) AS "Statut_Deploiement".';


--
-- Name: COLUMN "V_Niveau_2"."KmDPSANT"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."KmDPSANT" IS 'Distance enregistrée entre la DPS et l’antenne, en kilomètres. Expression projetée : n2."KmDPSANT".';


--
-- Name: COLUMN "V_Niveau_2"."ID_VoieAccesDPSANTFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_VoieAccesDPSANTFk" IS 'Voie d’accès entre la DPS et l’antenne. Expression projetée : n2."ID_VoieAccesDPSANTFk".';


--
-- Name: COLUMN "V_Niveau_2"."Voie_Acces_DPS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Voie_Acces_DPS" IS 'Abréviation de la voie d’accès DPS/antenne. Expression projetée : COALESCE(g_voie."AbrGenerique", '' ''::character varying) AS "Voie_Acces_DPS".';


--
-- Name: COLUMN "V_Niveau_2"."SelectNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_2"."SelectNiveau_2" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 2. Expression projetée : n2."SelectNiveau_2".';


--
-- Name: V_Niveau_3; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_3" AS
 SELECT n3."ID_TypeNiveau_2_Fk",
    COALESCE(g_type."AbrGenerique", ' '::character varying) AS "Type_Niveau_3",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n3."Alt_Niveau_3",
    n3."AbreNiveau_3",
    n3."CodeNiveau_3",
    n3."LatitudeNiveau_3",
    n3."PopulationNiveau_3",
    n3."LongitudeNiveau_3",
    n3."AltitudeNiveau_3",
    n3."EtenduNiveau_3",
    n3."surfaceNiveau_3",
    n3."geometryNiveau_3",
    n3."ObsNiveau_3",
    n3."ID_StatutNiveau_3_Fk",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "Statut_Niveau_3",
    n3."ID_StatutDeploieFk",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "Statut_Deploiement",
    n3."KmAntenneBCZS",
    n3."ID_VoieAccesANTBCZFk",
    COALESCE(g_voie1."AbrGenerique", ' '::character varying) AS "Voie_ANTBCZ",
    n3."KmDPSBCZS",
    n3."ID_VoieAccesDPSBCZFk",
    COALESCE(g_voie2."AbrGenerique", ' '::character varying) AS "Voie_DPSBCZS",
    n3."SelectNiveau_3",
    n3."ID_Niveau_2_FK"
   FROM ((((((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1a ON ((n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n3."ID_TypeNiveau_2_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n3."ID_StatutNiveau_3_Fk" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n3."ID_StatutDeploieFk" = g_deploiement."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie1 ON ((n3."ID_VoieAccesANTBCZFk" = g_voie1."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie2 ON ((n3."ID_VoieAccesDPSBCZFk" = g_voie2."ID_Generique")));


--
-- Name: VIEW "V_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_3" IS 'Vue de reference du Niveau 3 avec type, statut, deploiement, distances et voies d''acces.';


--
-- Name: COLUMN "V_Niveau_3"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n3."ID_TypeNiveau_2_Fk".';


--
-- Name: COLUMN "V_Niveau_3"."Type_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Type_Niveau_3" IS 'Abréviation du type d’unité de niveau 3 dans le référentiel. Expression projetée : COALESCE(g_type."AbrGenerique", '' ''::character varying) AS "Type_Niveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."Alt_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Alt_Niveau_3" IS 'Appellation alternative de l’unité de niveau 3. Expression projetée : n3."Alt_Niveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."AbreNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."AbreNiveau_3" IS 'Abréviation de l’unité géographique de niveau 3. Expression projetée : n3."AbreNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."CodeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."CodeNiveau_3" IS 'Code de référence de l’unité géographique de niveau 3. Expression projetée : n3."CodeNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."LatitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."LatitudeNiveau_3" IS 'Latitude enregistrée pour l’unité géographique de niveau 3. Expression projetée : n3."LatitudeNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."PopulationNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."PopulationNiveau_3" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 3. Expression projetée : n3."PopulationNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."LongitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."LongitudeNiveau_3" IS 'Longitude enregistrée pour l’unité géographique de niveau 3. Expression projetée : n3."LongitudeNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."AltitudeNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."AltitudeNiveau_3" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 3. Expression projetée : n3."AltitudeNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."EtenduNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."EtenduNiveau_3" IS 'Étendue descriptive déclarée pour l’unité géographique de niveau 3. Expression projetée : n3."EtenduNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."surfaceNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."surfaceNiveau_3" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 3. Expression projetée : n3."surfaceNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."geometryNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."geometryNiveau_3" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 3. Expression projetée : n3."geometryNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."ObsNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ObsNiveau_3" IS 'Observations sur l’unité géographique de niveau 3. Expression projetée : n3."ObsNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."ID_StatutNiveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_StatutNiveau_3_Fk" IS 'Statut de l’unité géographique dans le référentiel. Expression projetée : n3."ID_StatutNiveau_3_Fk".';


--
-- Name: COLUMN "V_Niveau_3"."Statut_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Statut_Niveau_3" IS 'Abréviation du statut de l’unité de niveau 3. Expression projetée : COALESCE(g_statut."AbrGenerique", '' ''::character varying) AS "Statut_Niveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."ID_StatutDeploieFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_StatutDeploieFk" IS 'Statut de déploiement enregistré pour l’unité de niveau 3. Expression projetée : n3."ID_StatutDeploieFk".';


--
-- Name: COLUMN "V_Niveau_3"."Statut_Deploiement"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Statut_Deploiement" IS 'Abréviation du statut de déploiement issu du référentiel. Expression projetée : COALESCE(g_deploiement."AbrGenerique", '' ''::character varying) AS "Statut_Deploiement".';


--
-- Name: COLUMN "V_Niveau_3"."KmAntenneBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."KmAntenneBCZS" IS 'Distance enregistrée entre l’antenne et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmAntenneBCZS".';


--
-- Name: COLUMN "V_Niveau_3"."ID_VoieAccesANTBCZFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_VoieAccesANTBCZFk" IS 'Voie d’accès entre l’antenne et le bureau central de zone de santé. Expression projetée : n3."ID_VoieAccesANTBCZFk".';


--
-- Name: COLUMN "V_Niveau_3"."Voie_ANTBCZ"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Voie_ANTBCZ" IS 'Abréviation de la voie d’accès antenne/bureau central de zone. Expression projetée : COALESCE(g_voie1."AbrGenerique", '' ''::character varying) AS "Voie_ANTBCZ".';


--
-- Name: COLUMN "V_Niveau_3"."KmDPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."KmDPSBCZS" IS 'Distance enregistrée entre la DPS et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmDPSBCZS".';


--
-- Name: COLUMN "V_Niveau_3"."ID_VoieAccesDPSBCZFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_VoieAccesDPSBCZFk" IS 'Voie d’accès entre la DPS et le bureau central de zone de santé. Expression projetée : n3."ID_VoieAccesDPSBCZFk".';


--
-- Name: COLUMN "V_Niveau_3"."Voie_DPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Voie_DPSBCZS" IS 'Abréviation de la voie d’accès DPS/bureau central de zone. Expression projetée : COALESCE(g_voie2."AbrGenerique", '' ''::character varying) AS "Voie_DPSBCZS".';


--
-- Name: COLUMN "V_Niveau_3"."SelectNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."SelectNiveau_3" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 3. Expression projetée : n3."SelectNiveau_3".';


--
-- Name: COLUMN "V_Niveau_3"."ID_Niveau_2_FK"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_2_FK" IS 'Unité géographique de rattachement de niveau 2. Expression projetée : n3."ID_Niveau_2_FK".';


--
-- Name: V_Niveau_4; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_4" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_TypeNiveau_4_Fk",
    COALESCE(g_type."AbrGenerique", ''::character varying) AS "Type_Niveau_4",
    n4."AbreNiveau_4",
    (((COALESCE(g_type."AbrGenerique", ''::character varying))::text || ' '::text) || (COALESCE(n4."NomNiveau_4", ''::character varying))::text) AS "SITE",
    n4."CodeNiveau_4",
    n4."PopulationNiveau_4",
    n4."LatitudeNiveau_4",
    n4."LongitudeNiveau_4",
    n4."AltitudeNiveau_4",
    n4."geometryNiveau_4",
    COALESCE(g_reseau."AbrGenerique", ' '::character varying) AS "RESEAU",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "VOIE_AS_ZS",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "STATUT_AS",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "STATUT_DEPLOI",
    n3."KmAntenneBCZS",
    n3."KmDPSBCZS",
    n4."ObsNiveau_4",
    n4."SelectNiveau_4",
    n4."ID_Niveau_4",
    n4."ID_Niveau_3_Fk",
    n4."NomNiveau_4",
    n4."KmZoneSanteAS",
    n4."surfaceNiveau_4",
    n4."ID_DispoReseauNiveau_4",
    n4."ID_VoieAccesZsASFk",
    n4."ID_StatutNiveau_4",
    n4."ID_StatutDeploiementFk"
   FROM (((((((((geolocalisation."T_Niveau_4" n4
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n4."ID_Niveau_3_Fk" = n3."ID_Niveau_3")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n4."ID_TypeNiveau_4_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n4."ID_VoieAccesZsASFk" = g_voie."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n4."ID_StatutNiveau_4" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n4."ID_StatutDeploiementFk" = g_deploiement."ID_Generique")))
  ORDER BY n0."NomNiveau_0", n1."NomNiveau_1", n2."NomNiveau_2", n3."NomNiveau_3", n4."NomNiveau_4";


--
-- Name: VIEW "V_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_4" IS 'Vue de reference du Niveau 4 avec hierarchie complete, identifiant de ligne, nom brut et indicateurs reseau/statut.';


--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';


--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';


--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';


--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';


--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';


--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';


--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: COLUMN "V_Niveau_4"."ID_TypeNiveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_TypeNiveau_4_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n4."ID_TypeNiveau_4_Fk".';


--
-- Name: COLUMN "V_Niveau_4"."Type_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."Type_Niveau_4" IS 'Abréviation du type d’unité de niveau 4 dans le référentiel. Expression projetée : COALESCE(g_type."AbrGenerique", ''''::character varying) AS "Type_Niveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."AbreNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AbreNiveau_4" IS 'Abréviation de l’unité géographique de niveau 4. Expression projetée : n4."AbreNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."SITE"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."SITE" IS 'Libellé de présentation composé de l’abréviation du type et du nom brut de l’unité ; ne remplace pas l’identifiant. Expression projetée : (COALESCE(g_type."AbrGenerique", ''''::character varying)::text || '' ''::text) || COALESCE(n4."NomNiveau_4", ''''::character varying)::text AS "SITE".';


--
-- Name: COLUMN "V_Niveau_4"."CodeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."CodeNiveau_4" IS 'Code de référence de l’unité géographique de niveau 4. Expression projetée : n4."CodeNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."PopulationNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."PopulationNiveau_4" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 4. Expression projetée : n4."PopulationNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."LatitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."LatitudeNiveau_4" IS 'Latitude enregistrée pour l’unité géographique de niveau 4. Expression projetée : n4."LatitudeNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."LongitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."LongitudeNiveau_4" IS 'Longitude enregistrée pour l’unité géographique de niveau 4. Expression projetée : n4."LongitudeNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."AltitudeNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AltitudeNiveau_4" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 4. Expression projetée : n4."AltitudeNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."geometryNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."geometryNiveau_4" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 4. Expression projetée : n4."geometryNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."RESEAU"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."RESEAU" IS 'Abréviation du statut de disponibilité réseau issu du référentiel. Expression projetée : COALESCE(g_reseau."AbrGenerique", '' ''::character varying) AS "RESEAU".';


--
-- Name: COLUMN "V_Niveau_4"."VOIE_AS_ZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."VOIE_AS_ZS" IS 'Abréviation de la voie d’accès entre aire et zone de santé. Expression projetée : COALESCE(g_voie."AbrGenerique", '' ''::character varying) AS "VOIE_AS_ZS".';


--
-- Name: COLUMN "V_Niveau_4"."STATUT_AS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."STATUT_AS" IS 'Abréviation du statut de l’aire de santé. Expression projetée : COALESCE(g_statut."AbrGenerique", '' ''::character varying) AS "STATUT_AS".';


--
-- Name: COLUMN "V_Niveau_4"."STATUT_DEPLOI"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."STATUT_DEPLOI" IS 'Abréviation du statut de déploiement issu du référentiel. Expression projetée : COALESCE(g_deploiement."AbrGenerique", '' ''::character varying) AS "STATUT_DEPLOI".';


--
-- Name: COLUMN "V_Niveau_4"."KmAntenneBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."KmAntenneBCZS" IS 'Distance enregistrée entre l’antenne et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmAntenneBCZS".';


--
-- Name: COLUMN "V_Niveau_4"."KmDPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."KmDPSBCZS" IS 'Distance enregistrée entre la DPS et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmDPSBCZS".';


--
-- Name: COLUMN "V_Niveau_4"."ObsNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ObsNiveau_4" IS 'Observations sur l’unité géographique de niveau 4. Expression projetée : n4."ObsNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."SelectNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."SelectNiveau_4" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 4. Expression projetée : n4."SelectNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_4" IS 'Identifiant de l’unité géographique de niveau 4. Expression projetée : n4."ID_Niveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_Niveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Expression projetée : n4."ID_Niveau_3_Fk".';


--
-- Name: COLUMN "V_Niveau_4"."NomNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."NomNiveau_4" IS 'Nom de l’unité géographique de niveau 4. Expression projetée : n4."NomNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."KmZoneSanteAS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."KmZoneSanteAS" IS 'Distance enregistrée entre la zone de santé et l’aire de santé, en kilomètres. Expression projetée : n4."KmZoneSanteAS".';


--
-- Name: COLUMN "V_Niveau_4"."surfaceNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."surfaceNiveau_4" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 4. Expression projetée : n4."surfaceNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."ID_DispoReseauNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_DispoReseauNiveau_4" IS 'Disponibilité du réseau déclarée pour l’unité géographique, dans le référentiel. Expression projetée : n4."ID_DispoReseauNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."ID_VoieAccesZsASFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_VoieAccesZsASFk" IS 'Voie d’accès entre la zone de santé et l’aire de santé. Expression projetée : n4."ID_VoieAccesZsASFk".';


--
-- Name: COLUMN "V_Niveau_4"."ID_StatutNiveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_StatutNiveau_4" IS 'Statut de l’unité géographique dans le référentiel. Expression projetée : n4."ID_StatutNiveau_4".';


--
-- Name: COLUMN "V_Niveau_4"."ID_StatutDeploiementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_4"."ID_StatutDeploiementFk" IS 'Statut de déploiement enregistré pour l’unité géographique. Expression projetée : n4."ID_StatutDeploiementFk".';


--
-- Name: V_Niveau_5; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Niveau_5" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n5."ID_TypeNiveau_5_Fk",
    COALESCE(g_type."AbrGenerique", ''::character varying) AS "Type_Niveau_5",
    (((COALESCE(g_type."AbrGenerique", ''::character varying))::text || ' '::text) || (COALESCE(n5."NomNiveau_5", ''::character varying))::text) AS "SITE",
    n5."AbreNiveau_5",
    n5."CodeNiveau_5",
    n5."PopulationNiveau_5",
    n5."LongitudeNiveau_5",
    n5."LatitudeNiveau_5",
    n5."AltitudeNiveau_5",
    n5."geometryNiveau_5",
    COALESCE(g_reseau."AbrGenerique", ' '::character varying) AS "RESEAU",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "VOIE_AS_Site",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "STATUT_Site",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "STATUT_DEPLOI",
    n3."KmAntenneBCZS",
    n3."KmDPSBCZS",
    n4."ID_Niveau_4",
    n5."ID_Niveau_5",
    n5."ID_Niveau_4_Fk",
    n5."ID_Niveau_3_Fk",
    n5."NomNiveau_5",
    n5."KmZoneSanteNiveau_5",
    n5."surfaceNiveau_5",
    n5."ID_DispoReseauNiveau_5",
    n5."ID_VoieAccesZsSiteFk",
    n5."ID_StatutNiveau_5",
    n5."ID_StatutDeploiementFk",
    n5."ID_TypeToitFk",
    n5."ObsNiveau_5",
    n5."SelectNiveau_5"
   FROM ((((((((((geolocalisation."T_Niveau_5" n5
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n5."ID_Niveau_4_Fk" = n4."ID_Niveau_4")))
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk") = n3."ID_Niveau_3")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n5."ID_TypeNiveau_5_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n5."ID_DispoReseauNiveau_5" = g_reseau."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n5."ID_VoieAccesZsSiteFk" = g_voie."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n5."ID_StatutNiveau_5" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n5."ID_StatutDeploiementFk" = g_deploiement."ID_Generique")))
  ORDER BY n0."NomNiveau_0", n1."NomNiveau_1", n2."NomNiveau_2", n3."NomNiveau_3", n5."NomNiveau_5";


--
-- Name: VIEW "V_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Niveau_5" IS 'Vue de reference du Niveau 5 avec identifiants de ligne, nom brut, reseau, statut et informations de site.';


--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';


--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';


--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';


--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';


--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';


--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';


--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: COLUMN "V_Niveau_5"."ID_TypeNiveau_5_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n5."ID_TypeNiveau_5_Fk".';


--
-- Name: COLUMN "V_Niveau_5"."Type_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."Type_Niveau_5" IS 'Abréviation du type d’unité de niveau 5 dans le référentiel. Expression projetée : COALESCE(g_type."AbrGenerique", ''''::character varying) AS "Type_Niveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."SITE"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."SITE" IS 'Libellé de présentation composé de l’abréviation du type et du nom brut de l’unité ; ne remplace pas l’identifiant. Expression projetée : (COALESCE(g_type."AbrGenerique", ''''::character varying)::text || '' ''::text) || COALESCE(n5."NomNiveau_5", ''''::character varying)::text AS "SITE".';


--
-- Name: COLUMN "V_Niveau_5"."AbreNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."AbreNiveau_5" IS 'Abréviation de l’unité géographique de niveau 5. Expression projetée : n5."AbreNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."CodeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."CodeNiveau_5" IS 'Code de référence de l’unité géographique de niveau 5. Expression projetée : n5."CodeNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."PopulationNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."PopulationNiveau_5" IS 'Population déclarée de l’unité géographique, exprimée en habitants de niveau 5. Expression projetée : n5."PopulationNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."LongitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."LongitudeNiveau_5" IS 'Longitude enregistrée pour l’unité géographique de niveau 5. Expression projetée : n5."LongitudeNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."LatitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."LatitudeNiveau_5" IS 'Latitude enregistrée pour l’unité géographique de niveau 5. Expression projetée : n5."LatitudeNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."AltitudeNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."AltitudeNiveau_5" IS 'Altitude déclarée pour l’unité géographique ; l’unité n’est pas imposée par le schéma de niveau 5. Expression projetée : n5."AltitudeNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."geometryNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."geometryNiveau_5" IS 'Géométrie de l’unité géographique conservée en texte ; aucun type spatial n’est imposé par cette colonne de niveau 5. Expression projetée : n5."geometryNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."RESEAU"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."RESEAU" IS 'Abréviation du statut de disponibilité réseau issu du référentiel. Expression projetée : COALESCE(g_reseau."AbrGenerique", '' ''::character varying) AS "RESEAU".';


--
-- Name: COLUMN "V_Niveau_5"."VOIE_AS_Site"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."VOIE_AS_Site" IS 'Abréviation de la voie d’accès zone/site selon le rattachement enregistré. Expression projetée : COALESCE(g_voie."AbrGenerique", '' ''::character varying) AS "VOIE_AS_Site".';


--
-- Name: COLUMN "V_Niveau_5"."STATUT_Site"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."STATUT_Site" IS 'Abréviation du statut du site. Expression projetée : COALESCE(g_statut."AbrGenerique", '' ''::character varying) AS "STATUT_Site".';


--
-- Name: COLUMN "V_Niveau_5"."STATUT_DEPLOI"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."STATUT_DEPLOI" IS 'Abréviation du statut de déploiement issu du référentiel. Expression projetée : COALESCE(g_deploiement."AbrGenerique", '' ''::character varying) AS "STATUT_DEPLOI".';


--
-- Name: COLUMN "V_Niveau_5"."KmAntenneBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."KmAntenneBCZS" IS 'Distance enregistrée entre l’antenne et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmAntenneBCZS".';


--
-- Name: COLUMN "V_Niveau_5"."KmDPSBCZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."KmDPSBCZS" IS 'Distance enregistrée entre la DPS et le bureau central de zone de santé, en kilomètres. Expression projetée : n3."KmDPSBCZS".';


--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_4" IS 'Identifiant de l’unité géographique de niveau 4. Expression projetée : n4."ID_Niveau_4".';


--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_5" IS 'Identifiant de l’unité géographique de niveau 5. Expression projetée : n5."ID_Niveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Expression projetée : n5."ID_Niveau_4_Fk".';


--
-- Name: COLUMN "V_Niveau_5"."ID_Niveau_3_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_Niveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Expression projetée : n5."ID_Niveau_3_Fk".';


--
-- Name: COLUMN "V_Niveau_5"."NomNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_5" IS 'Nom de l’unité géographique de niveau 5. Expression projetée : n5."NomNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."KmZoneSanteNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."KmZoneSanteNiveau_5" IS 'Distance enregistrée entre la zone de santé et le site, en kilomètres. Expression projetée : n5."KmZoneSanteNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."surfaceNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."surfaceNiveau_5" IS 'Surface déclarée de l’unité géographique conservée en texte ; l’unité n’est pas imposée par le schéma de niveau 5. Expression projetée : n5."surfaceNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."ID_DispoReseauNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_DispoReseauNiveau_5" IS 'Disponibilité du réseau déclarée pour l’unité géographique, dans le référentiel. Expression projetée : n5."ID_DispoReseauNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."ID_VoieAccesZsSiteFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_VoieAccesZsSiteFk" IS 'Voie d’accès entre la zone de santé et le site. Expression projetée : n5."ID_VoieAccesZsSiteFk".';


--
-- Name: COLUMN "V_Niveau_5"."ID_StatutNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_StatutNiveau_5" IS 'Statut de l’unité géographique dans le référentiel. Expression projetée : n5."ID_StatutNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."ID_StatutDeploiementFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_StatutDeploiementFk" IS 'Statut de déploiement enregistré pour l’unité géographique. Expression projetée : n5."ID_StatutDeploiementFk".';


--
-- Name: COLUMN "V_Niveau_5"."ID_TypeToitFk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_TypeToitFk" IS 'Type de toiture du site, issu du référentiel. Expression projetée : n5."ID_TypeToitFk".';


--
-- Name: COLUMN "V_Niveau_5"."ObsNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ObsNiveau_5" IS 'Observations sur l’unité géographique de niveau 5. Expression projetée : n5."ObsNiveau_5".';


--
-- Name: COLUMN "V_Niveau_5"."SelectNiveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Niveau_5"."SelectNiveau_5" IS 'Indicateur de sélection enregistré pour l’unité géographique de niveau 5. Expression projetée : n5."SelectNiveau_5".';


--
-- Name: V_Pop_N3_Couverte_Sites; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Pop_N3_Couverte_Sites" AS
 WITH sites AS (
         SELECT n5."ID_Niveau_5",
            n5."ID_Niveau_4_Fk",
            n5."ID_Niveau_3_Fk",
            n5."ID_TypeNiveau_5_Fk",
            n5."NomNiveau_5",
            n5."AbreNiveau_5",
            n5."CodeNiveau_5",
            n5."PopulationNiveau_5",
            n5."surfaceNiveau_5",
            n5."geometryNiveau_5",
            n5."ID_DispoReseauNiveau_5",
            n5."ID_VoieAccesZsSiteFk",
            n5."ID_StatutNiveau_5",
            n5."ID_StatutDeploiementFk",
            n5."ObsNiveau_5",
            n5."SelectNiveau_5",
            n5."ID_TypeToitFk",
            n5."KmZoneSanteNiveau_5",
            n5."LatitudeNiveau_5",
            n5."LongitudeNiveau_5",
            n5."AltitudeNiveau_5",
            COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk") AS region
           FROM (geolocalisation."T_Niveau_5" n5
             LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk")))
        )
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    s."ID_TypeNiveau_5_Fk",
    COALESCE(g."AbrGenerique", ' '::character varying) AS "Type_Niveau_5",
    sum(COALESCE(s."PopulationNiveau_5", (0)::numeric)) AS "Pop_Cum_Sites"
   FROM (((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n2."ID_Niveau_2" = n3."ID_Niveau_2_FK")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n1."ID_Niveau_1" = n2."ID_Niveau_1_FK")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n0."ID_Niveau_0" = n1."ID_Niveau_0_Fk")))
     LEFT JOIN sites s ON ((s.region = n3."ID_Niveau_3")))
     LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = s."ID_TypeNiveau_5_Fk")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3", s."ID_TypeNiveau_5_Fk", g."AbrGenerique";


--
-- Name: VIEW "V_Pop_N3_Couverte_Sites"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Pop_N3_Couverte_Sites" IS 'Population déclarée des sites par niveau 3 et type de site. Inclut le rattachement direct au niveau 3 et le repli par le niveau 4, comme V_Niveau_5 ; chaque site contribue une seule fois. Les populations absentes restent coalescées à zéro selon le contrat historique ; ce total ne prouve pas une couverture démographique sans chevauchement.';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."ID_TypeNiveau_5_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n5."ID_TypeNiveau_5_Fk".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."Type_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."Type_Niveau_5" IS 'Abréviation du type d’unité de niveau 5 dans le référentiel. Expression projetée : COALESCE(g_type5."AbrGenerique", '' ''::character varying) AS "Type_Niveau_5".';


--
-- Name: COLUMN "V_Pop_N3_Couverte_Sites"."Pop_Cum_Sites"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Pop_N3_Couverte_Sites"."Pop_Cum_Sites" IS 'Somme des populations déclarées des sites du groupe, avec rattachement direct au niveau 3 ou via le niveau 4 ; absence coalescée à zéro selon le contrat existant.';


--
-- Name: V_RESEAU_AS_par_ZS; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_RESEAU_AS_par_ZS" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    count(n4."ID_Niveau_4") AS "Nb_AS",
    sum(
        CASE
            WHEN ((g_reseau."AbrGenerique" IS NOT NULL) AND ((g_reseau."AbrGenerique")::text <> 'Sans reseau'::text)) THEN 1
            ELSE 0
        END) AS "Nb_AS_Avec_Reseau",
    round(((100.0 * (sum(
        CASE
            WHEN ((g_reseau."AbrGenerique" IS NOT NULL) AND ((g_reseau."AbrGenerique")::text <> 'Sans reseau'::text)) THEN 1
            ELSE 0
        END))::numeric) / (NULLIF(count(n4."ID_Niveau_4"), 0))::numeric), 1) AS "Pct_AS_Avec_Reseau"
   FROM (((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3";


--
-- Name: VIEW "V_RESEAU_AS_par_ZS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_RESEAU_AS_par_ZS" IS 'Vue d''indicateurs connectivite : nombre et pourcentage d''Aires de Sante avec reseau par Zone de Sante.';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."Nb_AS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."Nb_AS" IS 'Nombre d’aires de santé rattachées à la zone. Expression projetée : count(n4."ID_Niveau_4") AS "Nb_AS".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."Nb_AS_Avec_Reseau"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."Nb_AS_Avec_Reseau" IS 'Nombre d’aires dont l’abréviation réseau est non NULL et différente exactement de Sans reseau. Expression projetée : sum( CASE WHEN g_reseau."AbrGenerique" IS NOT NULL AND g_reseau."AbrGenerique"::text <> ''Sans reseau''::text THEN 1 ELSE 0 END) AS "Nb_AS_Avec_Reseau".';


--
-- Name: COLUMN "V_RESEAU_AS_par_ZS"."Pct_AS_Avec_Reseau"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_RESEAU_AS_par_ZS"."Pct_AS_Avec_Reseau" IS 'Pourcentage des aires déclarées avec réseau sur le nombre d’aires ; arrondi à une décimale et NULL si dénominateur nul. Expression projetée : round(100.0 * sum( CASE WHEN g_reseau."AbrGenerique" IS NOT NULL AND g_reseau."AbrGenerique"::text <> ''Sans reseau''::text THEN 1 ELSE 0 END)::numeric / NULLIF(count(n4."ID_Niveau_4"), 0)::numeric, 1) AS "Pct_AS_Avec_Reseau".';


--
-- Name: V_Stats_N1_N2; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Stats_N1_N2" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_TypeNiveau_2_Fk",
    COALESCE(g_type2."AbrGenerique", ' '::character varying) AS "Type_Niveau_2",
    count(DISTINCT n2."ID_Niveau_2") AS "Nb_Niveau_2",
    sum(COALESCE(n2."PopulationNiveau_2", (0)::numeric)) AS "Pop_Niveau_2"
   FROM (((geolocalisation."T_Niveau_1" n1
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n1."ID_Niveau_1" = n2."ID_Niveau_1_FK")))
     LEFT JOIN referentiel."T_Generique" g_type2 ON ((n2."ID_TypeNiveau_2_Fk" = g_type2."ID_Generique")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_TypeNiveau_2_Fk", g_type2."AbrGenerique";


--
-- Name: VIEW "V_Stats_N1_N2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Stats_N1_N2" IS 'Vue d''indicateurs structurels : nombre d''unites de Niveau 2 et population de Niveau 2 par Niveau 1 et type.';


--
-- Name: COLUMN "V_Stats_N1_N2"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';


--
-- Name: COLUMN "V_Stats_N1_N2"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_Stats_N1_N2"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';


--
-- Name: COLUMN "V_Stats_N1_N2"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';


--
-- Name: COLUMN "V_Stats_N1_N2"."ID_TypeNiveau_2_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."ID_TypeNiveau_2_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n2."ID_TypeNiveau_2_Fk".';


--
-- Name: COLUMN "V_Stats_N1_N2"."Type_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."Type_Niveau_2" IS 'Abréviation du type d’unité de niveau 2 dans le référentiel. Expression projetée : COALESCE(g_type2."AbrGenerique", '' ''::character varying) AS "Type_Niveau_2".';


--
-- Name: COLUMN "V_Stats_N1_N2"."Nb_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."Nb_Niveau_2" IS 'Nombre d’unités distinctes de niveau 2 pour le niveau 1 et le type considérés. Expression projetée : count(DISTINCT n2."ID_Niveau_2") AS "Nb_Niveau_2".';


--
-- Name: COLUMN "V_Stats_N1_N2"."Pop_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N1_N2"."Pop_Niveau_2" IS 'Somme des populations déclarées des unités de niveau 2 du groupe. Expression projetée : sum(COALESCE(n2."PopulationNiveau_2", 0::numeric)) AS "Pop_Niveau_2".';


--
-- Name: V_Stats_N3_Structures; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_Stats_N3_Structures" AS
 WITH structures AS (
         SELECT COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk") AS region,
            n4."ID_Niveau_4",
            n4."ID_TypeNiveau_4_Fk",
            n5."ID_Niveau_5",
            n5."ID_TypeNiveau_5_Fk"
           FROM (geolocalisation."T_Niveau_4" n4
             LEFT JOIN geolocalisation."T_Niveau_5" n5 ON ((n5."ID_Niveau_4_Fk" = n4."ID_Niveau_4")))
        UNION ALL
         SELECT n5."ID_Niveau_3_Fk",
            NULL::integer AS int4,
            NULL::integer AS int4,
            n5."ID_Niveau_5",
            n5."ID_TypeNiveau_5_Fk"
           FROM geolocalisation."T_Niveau_5" n5
          WHERE ((n5."ID_Niveau_4_Fk" IS NULL) AND (n5."ID_Niveau_3_Fk" IS NOT NULL))
        )
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    s."ID_TypeNiveau_4_Fk",
    COALESCE(g4."AbrGenerique", ' '::character varying) AS "Type_Niveau_4",
    s."ID_TypeNiveau_5_Fk",
    COALESCE(g5."AbrGenerique", ' '::character varying) AS "Type_Niveau_5",
    count(DISTINCT s."ID_Niveau_4") AS "Nb_Aires_Sante",
    count(DISTINCT s."ID_Niveau_5") AS "Nb_Structures_Sante"
   FROM ((((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n2."ID_Niveau_2" = n3."ID_Niveau_2_FK")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n1."ID_Niveau_1" = n2."ID_Niveau_1_FK")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n0."ID_Niveau_0" = n1."ID_Niveau_0_Fk")))
     LEFT JOIN structures s ON ((s.region = n3."ID_Niveau_3")))
     LEFT JOIN referentiel."T_Generique" g4 ON ((g4."ID_Generique" = s."ID_TypeNiveau_4_Fk")))
     LEFT JOIN referentiel."T_Generique" g5 ON ((g5."ID_Generique" = s."ID_TypeNiveau_5_Fk")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3", s."ID_TypeNiveau_4_Fk", g4."AbrGenerique", s."ID_TypeNiveau_5_Fk", g5."AbrGenerique";


--
-- Name: VIEW "V_Stats_N3_Structures"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_Stats_N3_Structures" IS 'Effectifs distincts par niveau 3 et paire de types niveau 4/niveau 5. Inclut les sites directement rattachés au niveau 3, sans leur inventer une aire de santé. Le nombre d’aires n’est pas additif entre groupes de types de sites.';


--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_TypeNiveau_4_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_TypeNiveau_4_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n4."ID_TypeNiveau_4_Fk".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."Type_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Type_Niveau_4" IS 'Abréviation du type d’unité de niveau 4 dans le référentiel. Expression projetée : COALESCE(g_type4."AbrGenerique", '' ''::character varying) AS "Type_Niveau_4".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."ID_TypeNiveau_5_Fk"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n5."ID_TypeNiveau_5_Fk".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."Type_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Type_Niveau_5" IS 'Abréviation du type d’unité de niveau 5 dans le référentiel. Expression projetée : COALESCE(g_type5."AbrGenerique", '' ''::character varying) AS "Type_Niveau_5".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."Nb_Aires_Sante"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Nb_Aires_Sante" IS 'Nombre d’aires de santé distinctes dans le groupe zone/types de structure. Expression projetée : count(DISTINCT n4."ID_Niveau_4") AS "Nb_Aires_Sante".';


--
-- Name: COLUMN "V_Stats_N3_Structures"."Nb_Structures_Sante"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_Stats_N3_Structures"."Nb_Structures_Sante" IS 'Nombre de sites distincts du groupe, par rattachement direct au niveau 3 ou via une aire ; aucun site direct n’est omis.';


--
-- Name: V_ZS_sans_AS; Type: VIEW; Schema: geolocalisation; Owner: -
--

CREATE VIEW geolocalisation."V_ZS_sans_AS" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3"
   FROM ((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk")))
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3"
 HAVING (count(n4."ID_Niveau_4") = 0);


--
-- Name: VIEW "V_ZS_sans_AS"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON VIEW geolocalisation."V_ZS_sans_AS" IS 'Vue de controle qualite : Zones de Sante (Niveau 3) sans Aire de Sante (Niveau 4).';


--
-- Name: COLUMN "V_ZS_sans_AS"."ID_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';


--
-- Name: COLUMN "V_ZS_sans_AS"."NomNiveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';


--
-- Name: COLUMN "V_ZS_sans_AS"."ID_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';


--
-- Name: COLUMN "V_ZS_sans_AS"."NomNiveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';


--
-- Name: COLUMN "V_ZS_sans_AS"."ID_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';


--
-- Name: COLUMN "V_ZS_sans_AS"."NomNiveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';


--
-- Name: COLUMN "V_ZS_sans_AS"."ID_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';


--
-- Name: COLUMN "V_ZS_sans_AS"."NomNiveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON COLUMN geolocalisation."V_ZS_sans_AS"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: T_Article_ID_Article_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Article" ALTER COLUMN "ID_Article" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_Article_ID_Article_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Article_ID_Article_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Article_ID_Article_seq" IS 'Séquence de génération de "logistique"."T_Article"."ID_Article". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Commande; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Commande" (
    "ID_Commande" integer CONSTRAINT "T_Commande_ID_Commande_not_null" NOT NULL,
    "ID_TypeCmdFk" integer,
    "ID_StatutCmdFk" integer,
    "ID_ClientFk" integer,
    "ID_UserFk" integer,
    "geolocalisationCmd" character varying(255),
    "DateHeureAutoCmd" timestamp with time zone,
    "DateCmd" timestamp with time zone,
    "CodeCmd" character varying(20),
    "RefCmd" character varying(255),
    "MontantHT" numeric(12,2),
    "MontantTTC" numeric(12,2),
    "UrlBL" character varying(255),
    "ObsCmd" character varying(255),
    "SelectCmd" boolean,
    "DateHeureAutoFacture" timestamp with time zone,
    "DateFacture" timestamp with time zone,
    "CodeFacture" character varying(255),
    "MontantRegleFacture" numeric(12,2),
    "MontantResteFacture" numeric(12,2),
    "StatusFacture" character varying(243),
    "ValideRemiseFacture" boolean,
    "UrlFacture" character varying(255),
    "ID_ConditionPaiementFk" integer,
    "DateEcheancePaiement" timestamp with time zone,
    "ID_ModePaiementFk" integer,
    "NomClientSaisi" character varying(255),
    CONSTRAINT chk_cmd_montants_non_negatifs CHECK (((("MontantHT" IS NULL) OR ("MontantHT" >= (0)::numeric)) AND (("MontantTTC" IS NULL) OR ("MontantTTC" >= (0)::numeric)) AND (("MontantRegleFacture" IS NULL) OR ("MontantRegleFacture" >= (0)::numeric)) AND (("MontantResteFacture" IS NULL) OR ("MontantResteFacture" >= (0)::numeric))))
);


--
-- Name: TABLE "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Commande" IS 'En-tête de commande d’entrée ou de sortie, avec tiers, dates, facturation et modalités de paiement. Le stock est affecté par les lignes et par leur réalignement lors d’un changement de type.';


--
-- Name: COLUMN "T_Commande"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_Commande" IS 'Identifiant de la commande.';


--
-- Name: COLUMN "T_Commande"."ID_TypeCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_TypeCmdFk" IS 'Type de commande dans la catégorie 64 ; son abréviation entr*/sort* détermine le sens du stock. Relation imposée : FOREIGN KEY ("ID_TypeCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Commande"."ID_StatutCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_StatutCmdFk" IS 'Statut de commande dans la nomenclature de catégorie 28. Relation imposée : FOREIGN KEY ("ID_StatutCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Commande"."ID_ClientFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_ClientFk" IS 'Identifiant client enregistré pour l’opération ; distinct du nom client saisi librement.';


--
-- Name: COLUMN "T_Commande"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_UserFk" IS 'Utilisateur rattaché à la commande. Relation imposée : FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE NOT VALID.';


--
-- Name: COLUMN "T_Commande"."geolocalisationCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."geolocalisationCmd" IS 'Localisation enregistrée librement pour la commande, sous forme textuelle.';


--
-- Name: COLUMN "T_Commande"."DateHeureAutoCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateHeureAutoCmd" IS 'Horodatage automatique enregistré pour la commande.';


--
-- Name: COLUMN "T_Commande"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateCmd" IS 'Date métier de la commande, distincte de son horodatage automatique.';


--
-- Name: COLUMN "T_Commande"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."CodeCmd" IS 'Référence métier unique de la commande ; les codes C_000E et C_000S sont exclus de la vue des commandes sans lignes.';


--
-- Name: COLUMN "T_Commande"."RefCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."RefCmd" IS 'Référence complémentaire de la commande.';


--
-- Name: COLUMN "T_Commande"."MontantHT"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."MontantHT" IS 'Montant hors taxes enregistré sur la commande ; la routine actuelle de totaux le calcule depuis les lignes.';


--
-- Name: COLUMN "T_Commande"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."MontantTTC" IS 'Montant toutes taxes comprises enregistré sur la commande ; la routine actuelle de totaux le fixe au même montant que MontantHT, sans calcul de taxe distinct.';


--
-- Name: COLUMN "T_Commande"."UrlBL"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."UrlBL" IS 'Référence du bon de livraison associé à la commande.';


--
-- Name: COLUMN "T_Commande"."ObsCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ObsCmd" IS 'Observations enregistrées sur la commande.';


--
-- Name: COLUMN "T_Commande"."SelectCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."SelectCmd" IS 'Indicateur de sélection enregistré sur la commande.';


--
-- Name: COLUMN "T_Commande"."DateHeureAutoFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateHeureAutoFacture" IS 'Horodatage automatique enregistré lors de la facturation.';


--
-- Name: COLUMN "T_Commande"."DateFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateFacture" IS 'Date métier de facturation.';


--
-- Name: COLUMN "T_Commande"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."CodeFacture" IS 'Référence unique de la facture attachée à la commande ; utilisée pour rattacher les règlements.';


--
-- Name: COLUMN "T_Commande"."MontantRegleFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."MontantRegleFacture" IS 'Montant réglé enregistré sur l’en-tête de facture ; distinct de la somme des écritures de règlement.';


--
-- Name: COLUMN "T_Commande"."MontantResteFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."MontantResteFacture" IS 'Reste enregistré sur l’en-tête de facture ; à distinguer du reste recalculé dans les vues.';


--
-- Name: COLUMN "T_Commande"."StatusFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."StatusFacture" IS 'Statut textuel enregistré de la facture ; le verrou SQL actuel compare exactement la valeur Clôturée.';


--
-- Name: COLUMN "T_Commande"."ValideRemiseFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ValideRemiseFacture" IS 'Indicateur de validation de remise enregistré sur la facture.';


--
-- Name: COLUMN "T_Commande"."UrlFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."UrlFacture" IS 'Référence du document de facture associé à la commande.';


--
-- Name: COLUMN "T_Commande"."ID_ConditionPaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_ConditionPaiementFk" IS 'Condition de paiement de la commande, dans la nomenclature de catégorie 37. Relation imposée : FOREIGN KEY ("ID_ConditionPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Commande"."DateEcheancePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateEcheancePaiement" IS 'Échéance de paiement de la facture ; utilisée pour les contrôles de retard.';


--
-- Name: COLUMN "T_Commande"."ID_ModePaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_ModePaiementFk" IS 'Mode de paiement prévu sur la commande, dans la nomenclature de catégorie 36. Relation imposée : FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Commande"."NomClientSaisi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."NomClientSaisi" IS 'Nom du client saisi librement sur la commande, distinct d’un rattachement par identifiant.';


--
-- Name: CONSTRAINT "T_Commande_ID_Commande_not_null" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Commande_ID_Commande_not_null" ON logistique."T_Commande" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Commande". Définition : NOT NULL "ID_Commande".';


--
-- Name: CONSTRAINT chk_cmd_montants_non_negatifs ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_cmd_montants_non_negatifs ON logistique."T_Commande" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Commande". Définition : CHECK (("MontantHT" IS NULL OR "MontantHT" >= 0::numeric) AND ("MontantTTC" IS NULL OR "MontantTTC" >= 0::numeric) AND ("MontantRegleFacture" IS NULL OR "MontantRegleFacture" >= 0::numeric) AND ("MontantResteFacture" IS NULL OR "MontantResteFacture" >= 0::numeric)).';


--
-- Name: T_CommandeDetail; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_CommandeDetail" (
    "ID_CmdFk" integer CONSTRAINT "T_CommandeDetail_ID_CmdFk_not_null" NOT NULL,
    "ID_ArticleFk" integer CONSTRAINT "T_CommandeDetail_ID_ArticleFk_not_null" NOT NULL,
    "QteCmdDetail" numeric(14,3),
    "PUCmdDetail" numeric(12,2),
    "ObsCmdDetail" text,
    "RemiseCmdDetail" boolean,
    "LieuCmdDetail" integer,
    "SelectCmdDetail" boolean,
    CONSTRAINT chk_cmddetail_qte_non_negative CHECK ((("QteCmdDetail" IS NULL) OR ("QteCmdDetail" >= (0)::numeric))),
    CONSTRAINT ck_ligne_prix_positif CHECK ((("PUCmdDetail" IS NULL) OR ("PUCmdDetail" >= (0)::numeric)))
);


--
-- Name: TABLE "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_CommandeDetail" IS 'Lignes de commande identifiées par le couple article/commande. Les routines appliquent les effets de stock, synchronisent les mouvements et recalculent les totaux ; les quantités fractionnaires sont refusées par les routines installées.';


--
-- Name: COLUMN "T_CommandeDetail"."ID_CmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."ID_CmdFk" IS 'Commande à laquelle appartient la ligne. Relation imposée : FOREIGN KEY ("ID_CmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: COLUMN "T_CommandeDetail"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."ID_ArticleFk" IS 'Article rattaché à la ligne ou au mouvement. Relation imposée : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE NOT VALID.';


--
-- Name: COLUMN "T_CommandeDetail"."QteCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."QteCmdDetail" IS 'Quantité de l’article sur la ligne ; les routines installées exigent une quantité strictement positive et entière pour l’impact stock.';


--
-- Name: COLUMN "T_CommandeDetail"."PUCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."PUCmdDetail" IS 'Prix unitaire propre à la ligne ; source du prix historique du mouvement de commande.';


--
-- Name: COLUMN "T_CommandeDetail"."ObsCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."ObsCmdDetail" IS 'Observations enregistrées sur la ligne de commande.';


--
-- Name: COLUMN "T_CommandeDetail"."RemiseCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."RemiseCmdDetail" IS 'Indicateur de remise enregistré sur la ligne ; ce booléen ne représente pas un taux de remise.';


--
-- Name: COLUMN "T_CommandeDetail"."LieuCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."LieuCmdDetail" IS 'Identifiant de lieu enregistré pour la ligne de commande ; sa signification dépend du paramétrage métier.';


--
-- Name: COLUMN "T_CommandeDetail"."SelectCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."SelectCmdDetail" IS 'Indicateur de sélection enregistré sur la ligne de commande.';


--
-- Name: CONSTRAINT "T_CommandeDetail_ID_CmdFk_not_null" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_CommandeDetail_ID_CmdFk_not_null" ON logistique."T_CommandeDetail" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_CommandeDetail". Définition : NOT NULL "ID_CmdFk".';


--
-- Name: CONSTRAINT "T_CommandeDetail_ID_ArticleFk_not_null" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_CommandeDetail_ID_ArticleFk_not_null" ON logistique."T_CommandeDetail" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_CommandeDetail". Définition : NOT NULL "ID_ArticleFk".';


--
-- Name: CONSTRAINT chk_cmddetail_qte_non_negative ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_cmddetail_qte_non_negative ON logistique."T_CommandeDetail" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_CommandeDetail". Définition : CHECK ("QteCmdDetail" IS NULL OR "QteCmdDetail" >= 0::numeric).';


--
-- Name: CONSTRAINT ck_ligne_prix_positif ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_ligne_prix_positif ON logistique."T_CommandeDetail" IS 'Intégrité imposée par PostgreSQL : CHECK ("PUCmdDetail" IS NULL OR "PUCmdDetail" >= 0::numeric)';


--
-- Name: T_Commande_ID_Commande_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Commande" ALTER COLUMN "ID_Commande" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_Commande_ID_Commande_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Commande_ID_Commande_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Commande_ID_Commande_seq" IS 'Séquence de génération de "logistique"."T_Commande"."ID_Commande". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Mouvement; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Mouvement" (
    "ID_Mvt" integer CONSTRAINT "T_Mouvement_ID_Mvt_not_null" NOT NULL,
    "ID_TypeMvtFk" integer,
    "ID_ArticleFk" integer,
    "ID_cmdFk" integer,
    "DateHeureAutoMvt" timestamp without time zone,
    "DateMvt" timestamp without time zone,
    "QteMvt" integer,
    "PUMvt" numeric(12,2),
    CONSTRAINT chk_mvt_qte_non_negative CHECK ((("QteMvt" IS NULL) OR ("QteMvt" >= 0)))
);


--
-- Name: TABLE "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Mouvement" IS 'Historique des entrées, sorties et ajustements d’article, avec type, quantité entière et prix du mouvement. Écritures réservées aux routines autorisées ; lecture pour audit et suivi du stock.';


--
-- Name: COLUMN "T_Mouvement"."ID_Mvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_Mvt" IS 'Identifiant du mouvement de stock.';


--
-- Name: COLUMN "T_Mouvement"."ID_TypeMvtFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_TypeMvtFk" IS 'Type historique du mouvement dans la catégorie 64 ; son abréviation détermine son signe de stock. Relation imposée : FOREIGN KEY ("ID_TypeMvtFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';


--
-- Name: COLUMN "T_Mouvement"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_ArticleFk" IS 'Article rattaché à la ligne ou au mouvement. Relation imposée : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Mouvement"."ID_cmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_cmdFk" IS 'Commande source du mouvement ; NULL pour un ajustement direct d’article. Relation imposée : FOREIGN KEY ("ID_cmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Mouvement"."DateHeureAutoMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."DateHeureAutoMvt" IS 'Horodatage automatique de création du mouvement, sans fuseau dans le type SQL.';


--
-- Name: COLUMN "T_Mouvement"."DateMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."DateMvt" IS 'Date métier du mouvement, utilisée dans les consommations et audits de stock.';


--
-- Name: COLUMN "T_Mouvement"."QteMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."QteMvt" IS 'Quantité entière du mouvement ; le signe entrée/sortie vient du type de mouvement, pas du signe de cette quantité.';


--
-- Name: COLUMN "T_Mouvement"."PUMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."PUMvt" IS 'Prix unitaire historique du mouvement : prix de ligne pour une commande, prix de vente article pour l’ajustement direct produit par le trigger actuel.';


--
-- Name: CONSTRAINT "T_Mouvement_ID_Mvt_not_null" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Mouvement_ID_Mvt_not_null" ON logistique."T_Mouvement" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Mouvement". Définition : NOT NULL "ID_Mvt".';


--
-- Name: CONSTRAINT chk_mvt_qte_non_negative ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_mvt_qte_non_negative ON logistique."T_Mouvement" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Mouvement". Définition : CHECK ("QteMvt" IS NULL OR "QteMvt" >= 0).';


--
-- Name: T_Mouvement_ID_Mvt_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Mouvement" ALTER COLUMN "ID_Mvt" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_Mouvement_ID_Mvt_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Mouvement_ID_Mvt_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Mouvement_ID_Mvt_seq" IS 'Séquence de génération de "logistique"."T_Mouvement"."ID_Mvt". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Reglements; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Reglements" (
    "ID_Reglement" integer CONSTRAINT "T_Reglements_ID_Reglement_not_null" NOT NULL,
    "CodeFactureFk" character varying(255),
    "ID_ModeReglementFk" integer CONSTRAINT "T_Reglements_ID_ModeReglementFk_not_null" NOT NULL,
    "ID_ClientFk" integer,
    "DateReglement" timestamp without time zone,
    "MontantRegle" numeric(12,2),
    CONSTRAINT chk_reglement_montant_non_negatif CHECK ((("MontantRegle" IS NULL) OR ("MontantRegle" >= (0)::numeric)))
);


--
-- Name: TABLE "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Reglements" IS 'Écritures de règlement rattachées à une facture de commande par CodeFactureFk. Grain : un règlement ; montant, date, mode et identifiant client enregistré.';


--
-- Name: COLUMN "T_Reglements"."ID_Reglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ID_Reglement" IS 'Identifiant de l’écriture de règlement.';


--
-- Name: COLUMN "T_Reglements"."CodeFactureFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."CodeFactureFk" IS 'Référence de facture de commande à laquelle s’applique le règlement. Relation imposée : FOREIGN KEY ("CodeFactureFk") REFERENCES logistique."T_Commande"("CodeFacture") NOT VALID.';


--
-- Name: COLUMN "T_Reglements"."ID_ModeReglementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ID_ModeReglementFk" IS 'Mode du règlement, dans la nomenclature de catégorie 36. Relation imposée : FOREIGN KEY ("ID_ModeReglementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Reglements"."ID_ClientFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ID_ClientFk" IS 'Identifiant client enregistré pour l’opération ; distinct du nom client saisi librement.';


--
-- Name: COLUMN "T_Reglements"."DateReglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."DateReglement" IS 'Date métier du règlement.';


--
-- Name: COLUMN "T_Reglements"."MontantRegle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."MontantRegle" IS 'Montant de cette écriture de règlement ; distinct du cumul des règlements de facture.';


--
-- Name: CONSTRAINT "T_Reglements_ID_Reglement_not_null" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Reglements_ID_Reglement_not_null" ON logistique."T_Reglements" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Reglements". Définition : NOT NULL "ID_Reglement".';


--
-- Name: CONSTRAINT "T_Reglements_ID_ModeReglementFk_not_null" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Reglements_ID_ModeReglementFk_not_null" ON logistique."T_Reglements" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Reglements". Définition : NOT NULL "ID_ModeReglementFk".';


--
-- Name: CONSTRAINT chk_reglement_montant_non_negatif ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_reglement_montant_non_negatif ON logistique."T_Reglements" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Reglements". Définition : CHECK ("MontantRegle" IS NULL OR "MontantRegle" >= 0::numeric).';


--
-- Name: T_Reglements_ID_Reglement_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Reglements" ALTER COLUMN "ID_Reglement" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_Reglements_ID_Reglement_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Reglements_ID_Reglement_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Reglements_ID_Reglement_seq" IS 'Séquence de génération de "logistique"."T_Reglements"."ID_Reglement". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: V_Article; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Article" AS
 SELECT a."ID_Article",
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
    (COALESCE(a."QteArticle", (0)::numeric))::numeric(14,3) AS "QteArticle",
    a."QteMinArticle",
    (GREATEST(((COALESCE(a."QteMinArticle", 0))::numeric - COALESCE(a."QteArticle", (0)::numeric)), (0)::numeric))::numeric(14,3) AS "QteACommander",
        CASE
            WHEN (COALESCE(a."QteArticle", (0)::numeric) <= (0)::numeric) THEN 'Rupture'::text
            WHEN ((a."QteMinArticle" IS NOT NULL) AND (COALESCE(a."QteArticle", (0)::numeric) <= (a."QteMinArticle")::numeric)) THEN 'Stock faible'::text
            ELSE 'Disponible'::text
        END AS "EtatStock",
    (COALESCE(a."QteArticle", (0)::numeric) <= (0)::numeric) AS "EstRupture",
    ((a."QteMinArticle" IS NOT NULL) AND (COALESCE(a."QteArticle", (0)::numeric) <= (a."QteMinArticle")::numeric)) AS "EstAlerteStock",
        CASE
            WHEN (COALESCE(a."QteArticle", (0)::numeric) <= (0)::numeric) THEN 1
            WHEN ((a."QteMinArticle" IS NOT NULL) AND (COALESCE(a."QteArticle", (0)::numeric) <= (a."QteMinArticle")::numeric)) THEN 2
            ELSE 3
        END AS "PrioriteStock",
    (COALESCE(a."PUArticle", (0)::numeric))::numeric(12,2) AS "PUArticle",
    (COALESCE(a."PVArticle", (0)::numeric))::numeric(12,2) AS "PVArticle",
    ((COALESCE(a."QteArticle", (0)::numeric) * COALESCE(a."PUArticle", (0)::numeric)))::numeric(14,2) AS "ValeurStockAchat",
    ((COALESCE(a."QteArticle", (0)::numeric) * COALESCE(a."PVArticle", (0)::numeric)))::numeric(14,2) AS "ValeurStockVente",
    ((COALESCE(a."PVArticle", (0)::numeric) - COALESCE(a."PUArticle", (0)::numeric)))::numeric(12,2) AS "MargeUnitaire",
        CASE
            WHEN (COALESCE(a."PUArticle", (0)::numeric) = (0)::numeric) THEN NULL::numeric
            ELSE round((((COALESCE(a."PVArticle", (0)::numeric) - COALESCE(a."PUArticle", (0)::numeric)) / NULLIF(a."PUArticle", (0)::numeric)) * (100)::numeric), 2)
        END AS "TauxMargePct",
    a."DatePeremptionArticle",
    a."DatePeremptionAlerteArticle",
    a."NbreJoursAlerteArticle",
        CASE
            WHEN (a."DatePeremptionArticle" IS NULL) THEN 'Non renseignée'::text
            WHEN ((a."DatePeremptionArticle")::date < CURRENT_DATE) THEN 'Périmé'::text
            WHEN ((a."DatePeremptionAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionAlerteArticle")::date <= CURRENT_DATE)) THEN 'Alerte péremption'::text
            WHEN ((a."NbreJoursAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle"))) THEN 'Alerte péremption'::text
            ELSE 'Valide'::text
        END AS "EtatPeremption",
        CASE
            WHEN (a."DatePeremptionArticle" IS NOT NULL) THEN ((a."DatePeremptionArticle")::date - CURRENT_DATE)
            ELSE NULL::integer
        END AS "JoursAvantPeremption",
    ((a."DatePeremptionArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date < CURRENT_DATE)) AS "EstPerime",
    ((a."DatePeremptionArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date >= CURRENT_DATE) AND (((a."DatePeremptionAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionAlerteArticle")::date <= CURRENT_DATE)) OR ((a."NbreJoursAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle"))))) AS "EstAlertePeremption",
        CASE
            WHEN (a."DatePeremptionArticle" IS NULL) THEN 4
            WHEN ((a."DatePeremptionArticle")::date < CURRENT_DATE) THEN 1
            WHEN (((a."DatePeremptionAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionAlerteArticle")::date <= CURRENT_DATE)) OR ((a."NbreJoursAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle")))) THEN 2
            ELSE 3
        END AS "PrioritePeremption",
    a."ID_UserFK",
    u."IdUser",
    NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text) AS "NomComplet",
        CASE
            WHEN (COALESCE(a."ValideArticle", true) = false) THEN 'Inactif'::text
            ELSE 'Actif'::text
        END AS "EtatArticle"
   FROM ((((logistique."T_Article" a
     LEFT JOIN referentiel."T_Generique" type_article ON (((a."ID_TypeArticleFk" = type_article."ID_Generique") AND (type_article."ID_CategorieGeneriqueFk" = 46))))
     LEFT JOIN referentiel."T_Generique" categorie_article ON (((a."ID_CategorieArticleFk" = categorie_article."ID_Generique") AND (categorie_article."ID_CategorieGeneriqueFk" = 40))))
     LEFT JOIN referentiel."T_Generique" unite ON (((a."ID_UniteFk" = unite."ID_Generique") AND (unite."ID_CategorieGeneriqueFk" = 34))))
     LEFT JOIN systeme."T_Utilisateurs" u ON ((a."ID_UserFK" = u."IdUser")));


--
-- Name: VIEW "V_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Article" IS 'Catalogue enrichi au grain article : nomenclatures, stock courant, seuils, prix, valorisations, péremption et utilisateur. Les états de stock et de péremption sont calculés à la lecture ; aucune restriction d’organisation n’est intégrée à la vue.';


--
-- Name: COLUMN "V_Article"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_Article" IS 'Identifiant de l’article. Expression projetée : a."ID_Article".';


--
-- Name: COLUMN "V_Article"."DateHeureAuto"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."DateHeureAuto" IS 'Horodatage automatique enregistré pour l’article. Expression projetée : a."DateHeureAuto".';


--
-- Name: COLUMN "V_Article"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."CodeArticleInterne" IS 'Référence interne unique de l’article. Expression projetée : a."CodeArticleInterne".';


--
-- Name: COLUMN "V_Article"."CodeArticleExterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."CodeArticleExterne" IS 'Code de l’article dans un référentiel externe, enregistré sous forme entière. Expression projetée : a."CodeArticleExterne".';


--
-- Name: COLUMN "V_Article"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."NomArticle" IS 'Libellé de l’article. Expression projetée : a."NomArticle".';


--
-- Name: COLUMN "V_Article"."RefArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."RefArticle" IS 'Référence descriptive complémentaire de l’article. Expression projetée : a."RefArticle".';


--
-- Name: COLUMN "V_Article"."PhotoArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."PhotoArticle" IS 'Référence de la photo de l’article. Expression projetée : a."PhotoArticle".';


--
-- Name: COLUMN "V_Article"."ObsArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ObsArticle" IS 'Observations enregistrées sur l’article. Expression projetée : a."ObsArticle".';


--
-- Name: COLUMN "V_Article"."ValideArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ValideArticle" IS 'Indique si l’article est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : a."ValideArticle".';


--
-- Name: COLUMN "V_Article"."ID_TypeArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_TypeArticleFk" IS 'Type d’article dans la nomenclature de catégorie 46. Expression projetée : a."ID_TypeArticleFk".';


--
-- Name: COLUMN "V_Article"."AbrTypeArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."AbrTypeArticle" IS 'Abréviation du type d’article. Expression projetée : type_article."AbrGenerique" AS "AbrTypeArticle".';


--
-- Name: COLUMN "V_Article"."TypeArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."TypeArticle" IS 'Libellé du type d’article. Expression projetée : type_article."NomGenerique" AS "TypeArticle".';


--
-- Name: COLUMN "V_Article"."ID_CategorieArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_CategorieArticleFk" IS 'Catégorie de l’article dans la nomenclature de catégorie 40. Expression projetée : a."ID_CategorieArticleFk".';


--
-- Name: COLUMN "V_Article"."AbrCategorieArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."AbrCategorieArticle" IS 'Abréviation de la catégorie d’article. Expression projetée : categorie_article."AbrGenerique" AS "AbrCategorieArticle".';


--
-- Name: COLUMN "V_Article"."CategorieArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."CategorieArticle" IS 'Libellé de la catégorie d’article. Expression projetée : categorie_article."NomGenerique" AS "CategorieArticle".';


--
-- Name: COLUMN "V_Article"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_UniteFk" IS 'Unité de référence de l’article, dans la nomenclature de catégorie 34. Expression projetée : a."ID_UniteFk".';


--
-- Name: COLUMN "V_Article"."AbrUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."AbrUnite" IS 'Abréviation de l’unité de référence de l’article. Expression projetée : unite."AbrGenerique" AS "AbrUnite".';


--
-- Name: COLUMN "V_Article"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."Unite" IS 'Libellé de l’unité de référence de l’article. Expression projetée : unite."NomGenerique" AS "Unite".';


--
-- Name: COLUMN "V_Article"."QteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."QteArticle" IS 'Stock courant officiel de l’article dans son unité de référence ; malgré le type décimal, les routines actuelles refusent les effets fractionnaires historisés en mouvements entiers. Expression projetée : COALESCE(a."QteArticle", 0::numeric)::numeric(14,3) AS "QteArticle".';


--
-- Name: COLUMN "V_Article"."QteMinArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."QteMinArticle" IS 'Seuil minimal de stock de l’article ; NULL signifie absence de seuil renseigné. Expression projetée : a."QteMinArticle".';


--
-- Name: COLUMN "V_Article"."QteACommander"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."QteACommander" IS 'Quantité nécessaire pour atteindre le seuil minimal, bornée à zéro ; ne tient pas compte des commandes ouvertes. Expression projetée : GREATEST(COALESCE(a."QteMinArticle", 0)::numeric - COALESCE(a."QteArticle", 0::numeric), 0::numeric)::numeric(14,3) AS "QteACommander".';


--
-- Name: COLUMN "V_Article"."EtatStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EtatStock" IS 'Qualification stock : Rupture si quantité <= 0, Stock faible si seuil renseigné et quantité <= seuil, sinon Disponible. Expression projetée : CASE WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN ''Rupture''::text WHEN a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN ''Stock faible''::text ELSE ''Disponible''::text END AS "EtatStock".';


--
-- Name: COLUMN "V_Article"."EstRupture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EstRupture" IS 'Vrai si le stock courant coalescé à zéro est inférieur ou égal à zéro. Expression projetée : COALESCE(a."QteArticle", 0::numeric) <= 0::numeric AS "EstRupture".';


--
-- Name: COLUMN "V_Article"."EstAlerteStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EstAlerteStock" IS 'Vrai si un seuil minimal est renseigné et si le stock courant est inférieur ou égal à ce seuil ; inclut potentiellement les ruptures. Expression projetée : a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric AS "EstAlerteStock".';


--
-- Name: COLUMN "V_Article"."PrioriteStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."PrioriteStock" IS 'Rang de priorité stock : 1 rupture, 2 seuil atteint, 3 disponible. Expression projetée : CASE WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 1 WHEN a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 2 ELSE 3 END AS "PrioriteStock".';


--
-- Name: COLUMN "V_Article"."PUArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."PUArticle" IS 'Prix unitaire d’achat enregistré sur l’article ; la devise n’est pas portée par cette table. Expression projetée : COALESCE(a."PUArticle", 0::numeric)::numeric(12,2) AS "PUArticle".';


--
-- Name: COLUMN "V_Article"."PVArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."PVArticle" IS 'Prix unitaire de vente enregistré sur l’article ; la devise n’est pas portée par cette table. Expression projetée : COALESCE(a."PVArticle", 0::numeric)::numeric(12,2) AS "PVArticle".';


--
-- Name: COLUMN "V_Article"."ValeurStockAchat"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ValeurStockAchat" IS 'Stock courant × prix unitaire d’achat, arrondi au type numérique de la vue ; aucune devise explicite dans cette source. Expression projetée : (COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PUArticle", 0::numeric))::numeric(14,2) AS "ValeurStockAchat".';


--
-- Name: COLUMN "V_Article"."ValeurStockVente"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ValeurStockVente" IS 'Stock courant × prix unitaire de vente ; aucune devise explicite dans cette source. Expression projetée : (COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PVArticle", 0::numeric))::numeric(14,2) AS "ValeurStockVente".';


--
-- Name: COLUMN "V_Article"."MargeUnitaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."MargeUnitaire" IS 'Prix de vente moins prix d’achat de l’article ; montant unitaire. Expression projetée : (COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric))::numeric(12,2) AS "MargeUnitaire".';


--
-- Name: COLUMN "V_Article"."TauxMargePct"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."TauxMargePct" IS 'Marge unitaire rapportée au prix d’achat × 100, arrondie à deux décimales ; NULL lorsque le prix d’achat vaut zéro. Expression projetée : CASE WHEN COALESCE(a."PUArticle", 0::numeric) = 0::numeric THEN NULL::numeric ELSE round((COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric)) / NULLIF(a."PUArticle", 0::numeric) * 100::numeric, 2) END AS "TauxMargePct".';


--
-- Name: COLUMN "V_Article"."DatePeremptionArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."DatePeremptionArticle" IS 'Date de péremption enregistrée pour l’article ; absence conservée comme date non renseignée dans la qualification. Expression projetée : a."DatePeremptionArticle".';


--
-- Name: COLUMN "V_Article"."DatePeremptionAlerteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."DatePeremptionAlerteArticle" IS 'Date explicite de début d’alerte avant péremption ; utilisée par les vues avec le délai d’alerte. Expression projetée : a."DatePeremptionAlerteArticle".';


--
-- Name: COLUMN "V_Article"."NbreJoursAlerteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."NbreJoursAlerteArticle" IS 'Nombre de jours avant péremption déclenchant une alerte dans la vue article. Expression projetée : a."NbreJoursAlerteArticle".';


--
-- Name: COLUMN "V_Article"."EtatPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EtatPeremption" IS 'Qualification à CURRENT_DATE : non renseignée, périmé, alerte péremption ou valide selon date et délai configurés. Expression projetée : CASE WHEN a."DatePeremptionArticle" IS NULL THEN ''Non renseignée''::text WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN ''Périmé''::text WHEN a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE THEN ''Alerte péremption''::text WHEN a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle") THEN ''Alerte péremption''::text ELSE ''Valide''::text END AS "EtatPeremption".';


--
-- Name: COLUMN "V_Article"."JoursAvantPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."JoursAvantPeremption" IS 'Date de péremption moins CURRENT_DATE, en jours ; NULL sans date. Expression projetée : CASE WHEN a."DatePeremptionArticle" IS NOT NULL THEN a."DatePeremptionArticle"::date - CURRENT_DATE ELSE NULL::integer END AS "JoursAvantPeremption".';


--
-- Name: COLUMN "V_Article"."EstPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EstPerime" IS 'Vrai si la date de péremption est strictement antérieure à CURRENT_DATE. Expression projetée : a."DatePeremptionArticle" IS NOT NULL AND a."DatePeremptionArticle"::date < CURRENT_DATE AS "EstPerime".';


--
-- Name: COLUMN "V_Article"."EstAlertePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EstAlertePeremption" IS 'Vrai pour un article non encore périmé dont la date ou le délai d’alerte est atteint. Expression projetée : a."DatePeremptionArticle" IS NOT NULL AND a."DatePeremptionArticle"::date >= CURRENT_DATE AND (a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE OR a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle")) AS "EstAlertePeremption".';


--
-- Name: COLUMN "V_Article"."PrioritePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."PrioritePeremption" IS 'Priorité : 1 périmé, 2 alerte, 3 valide, 4 date non renseignée. Expression projetée : CASE WHEN a."DatePeremptionArticle" IS NULL THEN 4 WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 1 WHEN a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE OR a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle") THEN 2 ELSE 3 END AS "PrioritePeremption".';


--
-- Name: COLUMN "V_Article"."ID_UserFK"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_UserFK" IS 'Utilisateur rattaché à l’article. Expression projetée : a."ID_UserFK".';


--
-- Name: COLUMN "V_Article"."IdUser"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."IdUser" IS 'Identifiant du compte utilisateur. Expression projetée : u."IdUser".';


--
-- Name: COLUMN "V_Article"."NomComplet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."NomComplet" IS 'Prénom et nom de l’utilisateur concaténés et nettoyés ; NULL lorsque le résultat est vide. Expression projetée : NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''''::character varying), '' '', COALESCE(u."NomUser", ''''::character varying))), ''''::text) AS "NomComplet".';


--
-- Name: COLUMN "V_Article"."EtatArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EtatArticle" IS 'Actif ou Inactif selon ValideArticle, avec repli actif pour la valeur absente dans cette vue. Expression projetée : CASE WHEN COALESCE(a."ValideArticle", true) = false THEN ''Inactif''::text ELSE ''Actif''::text END AS "EtatArticle".';


--
-- Name: V_AlertStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_AlertStock" AS
 SELECT "ID_Article",
    "CodeArticleInterne",
    "NomArticle",
    "AbrUnite",
    "QteArticle",
    "QteMinArticle",
    "QteACommander",
    ((COALESCE("QteArticle", (0)::numeric) - (COALESCE("QteMinArticle", 0))::numeric))::numeric(14,3) AS "Marge",
    "EtatStock",
    "EstRupture",
    "EstAlerteStock",
    "PrioriteStock",
    "EtatPeremption",
    "JoursAvantPeremption",
    "EstPerime",
    "EstAlertePeremption"
   FROM logistique."V_Article" a
  WHERE (("EstRupture" = true) OR ("EstAlerteStock" = true));


--
-- Name: VIEW "V_AlertStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_AlertStock" IS 'Articles en rupture ou au seuil minimal depuis V_Article, au grain article. Les ruptures sont incluses même sans seuil renseigné ; les autres alertes exigent le seuil défini dans V_Article.';


--
-- Name: COLUMN "V_AlertStock"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."ID_Article" IS 'Identifiant de l’article. Expression projetée : "ID_Article".';


--
-- Name: COLUMN "V_AlertStock"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."CodeArticleInterne" IS 'Référence interne unique de l’article. Expression projetée : "CodeArticleInterne".';


--
-- Name: COLUMN "V_AlertStock"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."NomArticle" IS 'Libellé de l’article. Expression projetée : "NomArticle".';


--
-- Name: COLUMN "V_AlertStock"."AbrUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."AbrUnite" IS 'Abréviation de l’unité de référence de l’article. Expression projetée : "AbrUnite".';


--
-- Name: COLUMN "V_AlertStock"."QteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."QteArticle" IS 'Stock courant officiel de l’article dans son unité de référence ; malgré le type décimal, les routines actuelles refusent les effets fractionnaires historisés en mouvements entiers. Expression projetée : "QteArticle".';


--
-- Name: COLUMN "V_AlertStock"."QteMinArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."QteMinArticle" IS 'Seuil minimal de stock de l’article ; NULL signifie absence de seuil renseigné. Expression projetée : "QteMinArticle".';


--
-- Name: COLUMN "V_AlertStock"."QteACommander"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."QteACommander" IS 'Quantité nécessaire pour atteindre le seuil minimal, bornée à zéro ; ne tient pas compte des commandes ouvertes. Expression projetée : "QteACommander".';


--
-- Name: COLUMN "V_AlertStock"."Marge"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."Marge" IS 'Écart entre stock courant et seuil minimal ; quantité dans l’unité de l’article, sans signification de marge financière. Expression projetée : (COALESCE("QteArticle", 0::numeric) - COALESCE("QteMinArticle", 0)::numeric)::numeric(14,3) AS "Marge".';


--
-- Name: COLUMN "V_AlertStock"."EtatStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."EtatStock" IS 'Qualification stock : Rupture si quantité <= 0, Stock faible si seuil renseigné et quantité <= seuil, sinon Disponible. Expression projetée : "EtatStock".';


--
-- Name: COLUMN "V_AlertStock"."EstRupture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."EstRupture" IS 'Vrai si le stock courant coalescé à zéro est inférieur ou égal à zéro. Expression projetée : "EstRupture".';


--
-- Name: COLUMN "V_AlertStock"."EstAlerteStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."EstAlerteStock" IS 'Vrai si un seuil minimal est renseigné et si le stock courant est inférieur ou égal à ce seuil ; inclut potentiellement les ruptures. Expression projetée : "EstAlerteStock".';


--
-- Name: COLUMN "V_AlertStock"."PrioriteStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."PrioriteStock" IS 'Rang de priorité stock : 1 rupture, 2 seuil atteint, 3 disponible. Expression projetée : "PrioriteStock".';


--
-- Name: COLUMN "V_AlertStock"."EtatPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."EtatPeremption" IS 'Qualification à CURRENT_DATE : non renseignée, périmé, alerte péremption ou valide selon date et délai configurés. Expression projetée : "EtatPeremption".';


--
-- Name: COLUMN "V_AlertStock"."JoursAvantPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."JoursAvantPeremption" IS 'Date de péremption moins CURRENT_DATE, en jours ; NULL sans date. Expression projetée : "JoursAvantPeremption".';


--
-- Name: COLUMN "V_AlertStock"."EstPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."EstPerime" IS 'Vrai si la date de péremption est strictement antérieure à CURRENT_DATE. Expression projetée : "EstPerime".';


--
-- Name: COLUMN "V_AlertStock"."EstAlertePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."EstAlertePeremption" IS 'Vrai pour un article non encore périmé dont la date ou le délai d’alerte est atteint. Expression projetée : "EstAlertePeremption".';


--
-- Name: V_AuditStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_AuditStock" AS
 SELECT "ID_Article",
    "CodeArticleInterne",
    "NomArticle",
    "StockArticle",
    "StockMouvements",
    "Ecart",
    "N_Mouvements",
    "QteEntree",
    "QteSortie",
    ("Ecart" = (0)::numeric) AS "EstStockCoherent",
        CASE
            WHEN ("Ecart" = (0)::numeric) THEN 'Cohérent'::text
            WHEN ("Ecart" > (0)::numeric) THEN 'Stock article supérieur aux mouvements'::text
            ELSE 'Stock article inférieur aux mouvements'::text
        END AS "EtatAuditStock"
   FROM logistique.fn_audit_stock(NULL::integer, NULL::timestamp without time zone) fn_audit_stock("ID_Article", "CodeArticleInterne", "NomArticle", "StockArticle", "StockMouvements", "Ecart", "N_Mouvements", "QteEntree", "QteSortie");


--
-- Name: VIEW "V_AuditStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_AuditStock" IS 'Audit courant au grain article depuis fn_audit_stock(NULL,NULL) : stock enregistré, somme des mouvements signés, écart, entrées/sorties et état de cohérence.';


--
-- Name: COLUMN "V_AuditStock"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."ID_Article" IS 'Identifiant de l’article. Expression projetée : "ID_Article".';


--
-- Name: COLUMN "V_AuditStock"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."CodeArticleInterne" IS 'Référence interne unique de l’article. Expression projetée : "CodeArticleInterne".';


--
-- Name: COLUMN "V_AuditStock"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."NomArticle" IS 'Libellé de l’article. Expression projetée : "NomArticle".';


--
-- Name: COLUMN "V_AuditStock"."StockArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."StockArticle" IS 'Stock courant enregistré de l’article ; ce n’est pas un stock historique à la date de borne. Expression projetée : "StockArticle".';


--
-- Name: COLUMN "V_AuditStock"."StockMouvements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."StockMouvements" IS 'Somme des quantités signées des mouvements retenus par la source d’audit. Expression projetée : "StockMouvements".';


--
-- Name: COLUMN "V_AuditStock"."Ecart"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."Ecart" IS 'Écart arithmétique stock enregistré moins stock calculé depuis les mouvements. Expression projetée : "Ecart".';


--
-- Name: COLUMN "V_AuditStock"."N_Mouvements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."N_Mouvements" IS 'Nombre de mouvements retenus pour l’article. Expression projetée : "N_Mouvements".';


--
-- Name: COLUMN "V_AuditStock"."QteEntree"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."QteEntree" IS 'Somme des quantités des mouvements de signe +1 retenus. Expression projetée : "QteEntree".';


--
-- Name: COLUMN "V_AuditStock"."QteSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."QteSortie" IS 'Somme des quantités des mouvements de signe -1 retenus. Expression projetée : "QteSortie".';


--
-- Name: COLUMN "V_AuditStock"."EstStockCoherent"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."EstStockCoherent" IS 'Vrai si l’écart entre stock enregistré et stock calculé est exactement nul. Expression projetée : "Ecart" = 0::numeric AS "EstStockCoherent".';


--
-- Name: COLUMN "V_AuditStock"."EtatAuditStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."EtatAuditStock" IS 'Libellé de cohérence selon le signe de l’écart entre stock enregistré et mouvements. Expression projetée : CASE WHEN "Ecart" = 0::numeric THEN ''Cohérent''::text WHEN "Ecart" > 0::numeric THEN ''Stock article supérieur aux mouvements''::text ELSE ''Stock article inférieur aux mouvements''::text END AS "EtatAuditStock".';


--
-- Name: V_MouvementStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_MouvementStock" AS
 SELECT m."ID_Mvt",
    m."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    m."ID_cmdFk",
    c."CodeCmd",
    c."DateCmd",
    c."ID_TypeCmdFk" AS "ID_TypeCmdActuel",
    m."DateHeureAutoMvt",
    m."DateMvt",
    m."ID_TypeMvtFk" AS "ID_TypeMvt",
    g."AbrGenerique" AS "AbrTypeMvt",
    g."NomGenerique" AS "TypeMvt",
    COALESCE(m."QteMvt", 0) AS "QteMvt",
    (COALESCE(m."PUMvt", (0)::numeric))::numeric(12,2) AS "PUMvt",
        CASE
            WHEN ((g."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
            WHEN ((g."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
            ELSE 0
        END AS "SigneStock",
    ((COALESCE(m."QteMvt", 0) *
        CASE
            WHEN ((g."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
            WHEN ((g."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
            ELSE 0
        END))::numeric AS "QteMvtSigned",
    (((COALESCE(m."QteMvt", 0))::numeric * COALESCE(m."PUMvt", (0)::numeric)))::numeric(14,2) AS "MontantMvt",
    ((((COALESCE(m."QteMvt", 0))::numeric * COALESCE(m."PUMvt", (0)::numeric)) * (
        CASE
            WHEN ((g."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
            WHEN ((g."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
            ELSE 0
        END)::numeric))::numeric(14,2) AS "MontantMvtSigned",
        CASE
            WHEN (m."ID_cmdFk" IS NULL) THEN 'Ajustement direct article'::text
            ELSE 'Commande'::text
        END AS "OrigineMouvement"
   FROM (((logistique."T_Mouvement" m
     LEFT JOIN logistique."T_Article" a ON ((a."ID_Article" = m."ID_ArticleFk")))
     LEFT JOIN logistique."T_Commande" c ON ((c."ID_Commande" = m."ID_cmdFk")))
     LEFT JOIN referentiel."T_Generique" g ON (((g."ID_Generique" = m."ID_TypeMvtFk") AND (g."ID_CategorieGeneriqueFk" = 64))));


--
-- Name: VIEW "V_MouvementStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_MouvementStock" IS 'Source commune au grain mouvement pour les calculs de stock : signe tiré du type historique catégorie 64, quantité/valeur signées et origine. Le type de commande actuel est exposé séparément.';


--
-- Name: COLUMN "V_MouvementStock"."ID_Mvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."ID_Mvt" IS 'Identifiant du mouvement de stock. Expression projetée : m."ID_Mvt".';


--
-- Name: COLUMN "V_MouvementStock"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."ID_ArticleFk" IS 'Article rattaché à la ligne ou au mouvement. Expression projetée : m."ID_ArticleFk".';


--
-- Name: COLUMN "V_MouvementStock"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."CodeArticleInterne" IS 'Référence interne unique de l’article. Expression projetée : a."CodeArticleInterne".';


--
-- Name: COLUMN "V_MouvementStock"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."NomArticle" IS 'Libellé de l’article. Expression projetée : a."NomArticle".';


--
-- Name: COLUMN "V_MouvementStock"."ID_cmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."ID_cmdFk" IS 'Commande source du mouvement ; NULL pour un ajustement direct d’article. Expression projetée : m."ID_cmdFk".';


--
-- Name: COLUMN "V_MouvementStock"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."CodeCmd" IS 'Référence métier unique de la commande ; les codes C_000E et C_000S sont exclus de la vue des commandes sans lignes. Expression projetée : c."CodeCmd".';


--
-- Name: COLUMN "V_MouvementStock"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."DateCmd" IS 'Date métier de la commande, distincte de son horodatage automatique. Expression projetée : c."DateCmd".';


--
-- Name: COLUMN "V_MouvementStock"."ID_TypeCmdActuel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."ID_TypeCmdActuel" IS 'Type actuellement enregistré sur la commande ; ne remplace pas le type historique du mouvement. Expression projetée : c."ID_TypeCmdFk" AS "ID_TypeCmdActuel".';


--
-- Name: COLUMN "V_MouvementStock"."DateHeureAutoMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."DateHeureAutoMvt" IS 'Horodatage automatique de création du mouvement, sans fuseau dans le type SQL. Expression projetée : m."DateHeureAutoMvt".';


--
-- Name: COLUMN "V_MouvementStock"."DateMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."DateMvt" IS 'Date métier du mouvement, utilisée dans les consommations et audits de stock. Expression projetée : m."DateMvt".';


--
-- Name: COLUMN "V_MouvementStock"."ID_TypeMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."ID_TypeMvt" IS 'Alias de l’identifiant du type historique de mouvement. Expression projetée : m."ID_TypeMvtFk" AS "ID_TypeMvt".';


--
-- Name: COLUMN "V_MouvementStock"."AbrTypeMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."AbrTypeMvt" IS 'Abréviation du type historique de mouvement. Expression projetée : g."AbrGenerique" AS "AbrTypeMvt".';


--
-- Name: COLUMN "V_MouvementStock"."TypeMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."TypeMvt" IS 'Libellé du type historique de mouvement ; la projection exacte dépend de la vue. Expression projetée : g."NomGenerique" AS "TypeMvt".';


--
-- Name: COLUMN "V_MouvementStock"."QteMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."QteMvt" IS 'Quantité entière du mouvement ; le signe entrée/sortie vient du type de mouvement, pas du signe de cette quantité. Expression projetée : COALESCE(m."QteMvt", 0) AS "QteMvt".';


--
-- Name: COLUMN "V_MouvementStock"."PUMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."PUMvt" IS 'Prix unitaire historique du mouvement : prix de ligne pour une commande, prix de vente article pour l’ajustement direct produit par le trigger actuel. Expression projetée : COALESCE(m."PUMvt", 0::numeric)::numeric(12,2) AS "PUMvt".';


--
-- Name: COLUMN "V_MouvementStock"."SigneStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."SigneStock" IS 'Signe du type historique : +1 pour entr*, -1 pour sort*, 0 sinon ; indépendant du type actuel de commande. Expression projetée : CASE WHEN g."AbrGenerique"::text ~~* ''entr%''::text THEN 1 WHEN g."AbrGenerique"::text ~~* ''sort%''::text THEN ''-1''::integer ELSE 0 END AS "SigneStock".';


--
-- Name: COLUMN "V_MouvementStock"."QteMvtSigned"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."QteMvtSigned" IS 'Quantité de mouvement multipliée par le signe du type historique. Expression projetée : (COALESCE(m."QteMvt", 0) * CASE WHEN g."AbrGenerique"::text ~~* ''entr%''::text THEN 1 WHEN g."AbrGenerique"::text ~~* ''sort%''::text THEN ''-1''::integer ELSE 0 END)::numeric AS "QteMvtSigned".';


--
-- Name: COLUMN "V_MouvementStock"."MontantMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."MontantMvt" IS 'Quantité × prix unitaire historique du mouvement. Expression projetée : (COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric))::numeric(14,2) AS "MontantMvt".';


--
-- Name: COLUMN "V_MouvementStock"."MontantMvtSigned"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."MontantMvtSigned" IS 'Quantité × prix historique × signe du type de mouvement. Expression projetée : (COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric) * CASE WHEN g."AbrGenerique"::text ~~* ''entr%''::text THEN 1 WHEN g."AbrGenerique"::text ~~* ''sort%''::text THEN ''-1''::integer ELSE 0 END::numeric)::numeric(14,2) AS "MontantMvtSigned".';


--
-- Name: COLUMN "V_MouvementStock"."OrigineMouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."OrigineMouvement" IS 'Commande si ID_cmdFk est renseigné, sinon Ajustement direct article. Expression projetée : CASE WHEN m."ID_cmdFk" IS NULL THEN ''Ajustement direct article''::text ELSE ''Commande''::text END AS "OrigineMouvement".';


--
-- Name: V_AuditStock_Theorique; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_AuditStock_Theorique" AS
 WITH mvt AS (
         SELECT v."ID_ArticleFk",
            sum(v."QteMvtSigned") AS stock_mouvement
           FROM logistique."V_MouvementStock" v
          GROUP BY v."ID_ArticleFk"
        )
 SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    COALESCE(a."QteArticle", (0)::numeric) AS "StockEnregistre",
    COALESCE(mvt.stock_mouvement, (0)::numeric) AS "StockCalcule",
    (COALESCE(a."QteArticle", (0)::numeric) - COALESCE(mvt.stock_mouvement, (0)::numeric)) AS "Ecart",
    ((COALESCE(a."QteArticle", (0)::numeric) - COALESCE(mvt.stock_mouvement, (0)::numeric)) = (0)::numeric) AS "EstStockCoherent"
   FROM (logistique."T_Article" a
     LEFT JOIN mvt ON ((mvt."ID_ArticleFk" = a."ID_Article")));


--
-- Name: VIEW "V_AuditStock_Theorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_AuditStock_Theorique" IS 'Rapprochement au grain article entre QteArticle courant et somme de V_MouvementStock.QteMvtSigned ; écart = stock enregistré moins stock calculé.';


--
-- Name: COLUMN "V_AuditStock_Theorique"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."ID_Article" IS 'Identifiant de l’article. Expression projetée : a."ID_Article".';


--
-- Name: COLUMN "V_AuditStock_Theorique"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."CodeArticleInterne" IS 'Référence interne unique de l’article. Expression projetée : a."CodeArticleInterne".';


--
-- Name: COLUMN "V_AuditStock_Theorique"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."NomArticle" IS 'Libellé de l’article. Expression projetée : a."NomArticle".';


--
-- Name: COLUMN "V_AuditStock_Theorique"."StockEnregistre"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."StockEnregistre" IS 'Stock courant QteArticle, coalescé à zéro dans cette vue. Expression projetée : COALESCE(a."QteArticle", 0::numeric) AS "StockEnregistre".';


--
-- Name: COLUMN "V_AuditStock_Theorique"."StockCalcule"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."StockCalcule" IS 'Somme des quantités signées de V_MouvementStock, coalescée à zéro. Expression projetée : COALESCE(mvt.stock_mouvement, 0::numeric) AS "StockCalcule".';


--
-- Name: COLUMN "V_AuditStock_Theorique"."Ecart"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."Ecart" IS 'Écart arithmétique stock enregistré moins stock calculé depuis les mouvements. Expression projetée : COALESCE(a."QteArticle", 0::numeric) - COALESCE(mvt.stock_mouvement, 0::numeric) AS "Ecart".';


--
-- Name: COLUMN "V_AuditStock_Theorique"."EstStockCoherent"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."EstStockCoherent" IS 'Vrai si l’écart entre stock enregistré et stock calculé est exactement nul. Expression projetée : (COALESCE(a."QteArticle", 0::numeric) - COALESCE(mvt.stock_mouvement, 0::numeric)) = 0::numeric AS "EstStockCoherent".';


--
-- Name: V_Commande; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Commande" AS
 WITH cd_stats AS (
         SELECT cd."ID_CmdFk",
            (count(*))::integer AS "NbLignes",
            (count(DISTINCT cd."ID_ArticleFk"))::integer AS "NbArticlesDistincts",
            (COALESCE(sum(COALESCE(cd."QteCmdDetail", (0)::numeric)), (0)::numeric))::numeric(14,3) AS "QteTotale",
            (COALESCE(sum((COALESCE(cd."QteCmdDetail", (0)::numeric) * COALESCE(cd."PUCmdDetail", (0)::numeric))), (0)::numeric))::numeric(12,2) AS "MontantDetails",
            string_agg(DISTINCT (a."NomArticle")::text, ', '::text ORDER BY (a."NomArticle")::text) AS "ListeArticles"
           FROM (logistique."T_CommandeDetail" cd
             LEFT JOIN logistique."T_Article" a ON ((a."ID_Article" = cd."ID_ArticleFk")))
          GROUP BY cd."ID_CmdFk"
        ), reg_stats AS (
         SELECT r."CodeFactureFk",
            (COALESCE(sum(COALESCE(r."MontantRegle", (0)::numeric)), (0)::numeric))::numeric(12,2) AS "TotalRegleReel",
            (count(*))::integer AS "NbReglements",
            max(r."DateReglement") AS "DernierReglement"
           FROM logistique."T_Reglements" r
          GROUP BY r."CodeFactureFk"
        )
 SELECT c."ID_Commande",
    c."ID_TypeCmdFk",
    c."ID_StatutCmdFk",
    c."ID_ClientFk",
    c."ID_UserFk",
    c."geolocalisationCmd",
    c."DateHeureAutoCmd",
    c."DateCmd",
    c."CodeCmd",
    c."RefCmd",
    c."MontantHT",
    c."MontantTTC",
    c."UrlBL",
    c."ObsCmd",
    c."SelectCmd",
    c."DateHeureAutoFacture",
    c."DateFacture",
    c."CodeFacture",
    c."MontantRegleFacture",
    c."MontantResteFacture",
    c."StatusFacture",
    c."ValideRemiseFacture",
    c."UrlFacture",
    c."ID_ConditionPaiementFk",
    c."DateEcheancePaiement",
    c."ID_ModePaiementFk",
    c."NomClientSaisi",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    type_cmd."NomGenerique" AS "TypeCmd",
        CASE
            WHEN ((type_cmd."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
            WHEN ((type_cmd."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
            ELSE 0
        END AS "SigneCommande",
    COALESCE(((type_cmd."AbrGenerique")::text ~~* 'entr%'::text), false) AS "EstCommandeEntree",
    COALESCE(((type_cmd."AbrGenerique")::text ~~* 'sort%'::text), false) AS "EstCommandeSortie",
    statut_cmd."AbrGenerique" AS "AbrStatutCmd",
    statut_cmd."NomGenerique" AS "StatutCmd",
    u."NomUser",
    u."PrenomUser",
    NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text) AS "NomComplet",
    condition_paiement."AbrGenerique" AS "AbrConditionPaiement",
    condition_paiement."NomGenerique" AS "ConditionPaiement",
    mode_paiement."AbrGenerique" AS "AbrModePaiement",
    mode_paiement."NomGenerique" AS "ModePaiement",
    (COALESCE(c."MontantHT", (0)::numeric))::numeric(12,2) AS "MontantHTCalc",
    (COALESCE(c."MontantTTC", (0)::numeric))::numeric(12,2) AS "MontantTTCCalc",
    (COALESCE(c."MontantRegleFacture", (0)::numeric))::numeric(12,2) AS "MontantRegleFactureCalc",
    (COALESCE(c."MontantResteFacture", (0)::numeric))::numeric(12,2) AS "MontantResteFactureCalc",
    (COALESCE(reg_stats."TotalRegleReel", (0)::numeric))::numeric(12,2) AS "TotalRegleReel",
    ((COALESCE(c."MontantTTC", (0)::numeric) - COALESCE(reg_stats."TotalRegleReel", (0)::numeric)))::numeric(12,2) AS "ResteReel",
    COALESCE(reg_stats."NbReglements", 0) AS "NbReglements",
    reg_stats."DernierReglement",
        CASE
            WHEN (c."CodeFacture" IS NULL) THEN 'Non facturée'::text
            WHEN (COALESCE(c."MontantTTC", (0)::numeric) = (0)::numeric) THEN 'Montant nul'::text
            WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", (0)::numeric), (0)::numeric) <= (0)::numeric) THEN 'Non réglée'::text
            WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", (0)::numeric), (0)::numeric) < COALESCE(c."MontantTTC", (0)::numeric)) THEN 'Partiellement réglée'::text
            WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", (0)::numeric), (0)::numeric) >= COALESCE(c."MontantTTC", (0)::numeric)) THEN 'Réglée'::text
            ELSE 'Indéterminé'::text
        END AS "EtatPaiement",
    ((c."DateEcheancePaiement" IS NOT NULL) AND ((c."DateEcheancePaiement")::date < CURRENT_DATE) AND ((COALESCE(c."MontantTTC", (0)::numeric) - COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", (0)::numeric), (0)::numeric)) > (0)::numeric)) AS "EstPaiementEnRetard",
        CASE
            WHEN (c."DateEcheancePaiement" IS NOT NULL) THEN ((c."DateEcheancePaiement")::date - CURRENT_DATE)
            ELSE NULL::integer
        END AS "JoursAvantEcheance",
    COALESCE(cd_stats."NbLignes", 0) AS "NbLignes",
    COALESCE(cd_stats."NbArticlesDistincts", 0) AS "NbArticlesDistincts",
    (COALESCE(cd_stats."QteTotale", (0)::numeric))::numeric(14,3) AS "QteTotale",
    (COALESCE(cd_stats."MontantDetails", (0)::numeric))::numeric(12,2) AS "MontantDetails",
    cd_stats."ListeArticles",
    (COALESCE(cd_stats."NbLignes", 0) = 0) AS "EstCommandeSansDetails",
    ((COALESCE(c."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric)))::numeric(12,2) AS "EcartMontantDetails",
    (abs((COALESCE(c."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric))) > 0.01) AS "EstMontantIncoherent",
        CASE
            WHEN (COALESCE(cd_stats."NbLignes", 0) = 0) THEN 'Sans détails'::text
            WHEN (abs((COALESCE(c."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric))) > 0.01) THEN 'Montant incohérent'::text
            ELSE 'Cohérente'::text
        END AS "EtatControleCommande"
   FROM (((((((logistique."T_Commande" c
     LEFT JOIN systeme."T_Utilisateurs" u ON ((c."ID_UserFk" = u."IdUser")))
     LEFT JOIN referentiel."T_Generique" type_cmd ON (((c."ID_TypeCmdFk" = type_cmd."ID_Generique") AND (type_cmd."ID_CategorieGeneriqueFk" = 64))))
     LEFT JOIN referentiel."T_Generique" statut_cmd ON (((c."ID_StatutCmdFk" = statut_cmd."ID_Generique") AND (statut_cmd."ID_CategorieGeneriqueFk" = 28))))
     LEFT JOIN referentiel."T_Generique" condition_paiement ON (((c."ID_ConditionPaiementFk" = condition_paiement."ID_Generique") AND (condition_paiement."ID_CategorieGeneriqueFk" = 37))))
     LEFT JOIN referentiel."T_Generique" mode_paiement ON (((c."ID_ModePaiementFk" = mode_paiement."ID_Generique") AND (mode_paiement."ID_CategorieGeneriqueFk" = 36))))
     LEFT JOIN cd_stats ON ((cd_stats."ID_CmdFk" = c."ID_Commande")))
     LEFT JOIN reg_stats ON (((reg_stats."CodeFactureFk")::text = (c."CodeFacture")::text)));


--
-- Name: VIEW "V_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Commande" IS 'Suivi au grain commande : en-tête, nomenclatures, agrégats de lignes et règlements, reste, échéance et contrôles de cohérence. L’autorisation et le périmètre d’organisation relèvent du consommateur serveur.';


--
-- Name: COLUMN "V_Commande"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_Commande" IS 'Identifiant de la commande. Expression projetée : c."ID_Commande".';


--
-- Name: COLUMN "V_Commande"."ID_TypeCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_TypeCmdFk" IS 'Type de commande dans la catégorie 64 ; son abréviation entr*/sort* détermine le sens du stock. Expression projetée : c."ID_TypeCmdFk".';


--
-- Name: COLUMN "V_Commande"."ID_StatutCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_StatutCmdFk" IS 'Statut de commande dans la nomenclature de catégorie 28. Expression projetée : c."ID_StatutCmdFk".';


--
-- Name: COLUMN "V_Commande"."ID_ClientFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_ClientFk" IS 'Identifiant client enregistré pour l’opération ; distinct du nom client saisi librement. Expression projetée : c."ID_ClientFk".';


--
-- Name: COLUMN "V_Commande"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_UserFk" IS 'Utilisateur rattaché à la commande. Expression projetée : c."ID_UserFk".';


--
-- Name: COLUMN "V_Commande"."geolocalisationCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."geolocalisationCmd" IS 'Localisation enregistrée librement pour la commande, sous forme textuelle. Expression projetée : c."geolocalisationCmd".';


--
-- Name: COLUMN "V_Commande"."DateHeureAutoCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DateHeureAutoCmd" IS 'Horodatage automatique enregistré pour la commande. Expression projetée : c."DateHeureAutoCmd".';


--
-- Name: COLUMN "V_Commande"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DateCmd" IS 'Date métier de la commande, distincte de son horodatage automatique. Expression projetée : c."DateCmd".';


--
-- Name: COLUMN "V_Commande"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."CodeCmd" IS 'Référence métier unique de la commande ; les codes C_000E et C_000S sont exclus de la vue des commandes sans lignes. Expression projetée : c."CodeCmd".';


--
-- Name: COLUMN "V_Commande"."RefCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."RefCmd" IS 'Référence complémentaire de la commande. Expression projetée : c."RefCmd".';


--
-- Name: COLUMN "V_Commande"."MontantHT"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantHT" IS 'Montant hors taxes enregistré sur la commande ; la routine actuelle de totaux le calcule depuis les lignes. Expression projetée : c."MontantHT".';


--
-- Name: COLUMN "V_Commande"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantTTC" IS 'Montant toutes taxes comprises enregistré sur la commande ; la routine actuelle de totaux le fixe au même montant que MontantHT, sans calcul de taxe distinct. Expression projetée : c."MontantTTC".';


--
-- Name: COLUMN "V_Commande"."UrlBL"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."UrlBL" IS 'Référence du bon de livraison associé à la commande. Expression projetée : c."UrlBL".';


--
-- Name: COLUMN "V_Commande"."ObsCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ObsCmd" IS 'Observations enregistrées sur la commande. Expression projetée : c."ObsCmd".';


--
-- Name: COLUMN "V_Commande"."SelectCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."SelectCmd" IS 'Indicateur de sélection enregistré sur la commande. Expression projetée : c."SelectCmd".';


--
-- Name: COLUMN "V_Commande"."DateHeureAutoFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DateHeureAutoFacture" IS 'Horodatage automatique enregistré lors de la facturation. Expression projetée : c."DateHeureAutoFacture".';


--
-- Name: COLUMN "V_Commande"."DateFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DateFacture" IS 'Date métier de facturation. Expression projetée : c."DateFacture".';


--
-- Name: COLUMN "V_Commande"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."CodeFacture" IS 'Référence unique de la facture attachée à la commande ; utilisée pour rattacher les règlements. Expression projetée : c."CodeFacture".';


--
-- Name: COLUMN "V_Commande"."MontantRegleFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantRegleFacture" IS 'Montant réglé enregistré sur l’en-tête de facture ; distinct de la somme des écritures de règlement. Expression projetée : c."MontantRegleFacture".';


--
-- Name: COLUMN "V_Commande"."MontantResteFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantResteFacture" IS 'Reste enregistré sur l’en-tête de facture ; à distinguer du reste recalculé dans les vues. Expression projetée : c."MontantResteFacture".';


--
-- Name: COLUMN "V_Commande"."StatusFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."StatusFacture" IS 'Statut textuel enregistré de la facture ; le verrou SQL actuel compare exactement la valeur Clôturée. Expression projetée : c."StatusFacture".';


--
-- Name: COLUMN "V_Commande"."ValideRemiseFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ValideRemiseFacture" IS 'Indicateur de validation de remise enregistré sur la facture. Expression projetée : c."ValideRemiseFacture".';


--
-- Name: COLUMN "V_Commande"."UrlFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."UrlFacture" IS 'Référence du document de facture associé à la commande. Expression projetée : c."UrlFacture".';


--
-- Name: COLUMN "V_Commande"."ID_ConditionPaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_ConditionPaiementFk" IS 'Condition de paiement de la commande, dans la nomenclature de catégorie 37. Expression projetée : c."ID_ConditionPaiementFk".';


--
-- Name: COLUMN "V_Commande"."DateEcheancePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DateEcheancePaiement" IS 'Échéance de paiement de la facture ; utilisée pour les contrôles de retard. Expression projetée : c."DateEcheancePaiement".';


--
-- Name: COLUMN "V_Commande"."ID_ModePaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_ModePaiementFk" IS 'Mode de paiement prévu sur la commande, dans la nomenclature de catégorie 36. Expression projetée : c."ID_ModePaiementFk".';


--
-- Name: COLUMN "V_Commande"."NomClientSaisi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."NomClientSaisi" IS 'Nom du client saisi librement sur la commande, distinct d’un rattachement par identifiant. Expression projetée : c."NomClientSaisi".';


--
-- Name: COLUMN "V_Commande"."AbrTypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."AbrTypeCmd" IS 'Abréviation du type de commande issu de la catégorie 64. Expression projetée : type_cmd."AbrGenerique" AS "AbrTypeCmd".';


--
-- Name: COLUMN "V_Commande"."TypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."TypeCmd" IS 'Libellé du type de commande issu de la catégorie 64. Expression projetée : type_cmd."NomGenerique" AS "TypeCmd".';


--
-- Name: COLUMN "V_Commande"."SigneCommande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."SigneCommande" IS 'Sens du stock d’après l’abréviation du type : +1 pour entr*, -1 pour sort*, 0 sinon. Expression projetée : CASE WHEN type_cmd."AbrGenerique"::text ~~* ''entr%''::text THEN 1 WHEN type_cmd."AbrGenerique"::text ~~* ''sort%''::text THEN ''-1''::integer ELSE 0 END AS "SigneCommande".';


--
-- Name: COLUMN "V_Commande"."EstCommandeEntree"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EstCommandeEntree" IS 'Vrai si l’abréviation du type de commande commence par entr, sans distinction de casse. Expression projetée : COALESCE(type_cmd."AbrGenerique"::text ~~* ''entr%''::text, false) AS "EstCommandeEntree".';


--
-- Name: COLUMN "V_Commande"."EstCommandeSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EstCommandeSortie" IS 'Vrai si l’abréviation du type de commande commence par sort, sans distinction de casse. Expression projetée : COALESCE(type_cmd."AbrGenerique"::text ~~* ''sort%''::text, false) AS "EstCommandeSortie".';


--
-- Name: COLUMN "V_Commande"."AbrStatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."AbrStatutCmd" IS 'Abréviation du statut de commande. Expression projetée : statut_cmd."AbrGenerique" AS "AbrStatutCmd".';


--
-- Name: COLUMN "V_Commande"."StatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."StatutCmd" IS 'Libellé du statut de commande. Expression projetée : statut_cmd."NomGenerique" AS "StatutCmd".';


--
-- Name: COLUMN "V_Commande"."NomUser"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."NomUser" IS 'Nom de l’utilisateur. Expression projetée : u."NomUser".';


--
-- Name: COLUMN "V_Commande"."PrenomUser"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."PrenomUser" IS 'Prénom de l’utilisateur. Expression projetée : u."PrenomUser".';


--
-- Name: COLUMN "V_Commande"."NomComplet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."NomComplet" IS 'Prénom et nom de l’utilisateur concaténés et nettoyés ; NULL lorsque le résultat est vide. Expression projetée : NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''''::character varying), '' '', COALESCE(u."NomUser", ''''::character varying))), ''''::text) AS "NomComplet".';


--
-- Name: COLUMN "V_Commande"."AbrConditionPaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."AbrConditionPaiement" IS 'Abréviation de la condition de paiement. Expression projetée : condition_paiement."AbrGenerique" AS "AbrConditionPaiement".';


--
-- Name: COLUMN "V_Commande"."ConditionPaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ConditionPaiement" IS 'Libellé de la condition de paiement. Expression projetée : condition_paiement."NomGenerique" AS "ConditionPaiement".';


--
-- Name: COLUMN "V_Commande"."AbrModePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."AbrModePaiement" IS 'Abréviation du mode de paiement prévu. Expression projetée : mode_paiement."AbrGenerique" AS "AbrModePaiement".';


--
-- Name: COLUMN "V_Commande"."ModePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ModePaiement" IS 'Libellé du mode de paiement prévu. Expression projetée : mode_paiement."NomGenerique" AS "ModePaiement".';


--
-- Name: COLUMN "V_Commande"."MontantHTCalc"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantHTCalc" IS 'MontantHT de l’en-tête coalescé à zéro ; ne correspond pas à un nouveau calcul depuis les lignes. Expression projetée : COALESCE(c."MontantHT", 0::numeric)::numeric(12,2) AS "MontantHTCalc".';


--
-- Name: COLUMN "V_Commande"."MontantTTCCalc"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantTTCCalc" IS 'MontantTTC de l’en-tête coalescé à zéro. Expression projetée : COALESCE(c."MontantTTC", 0::numeric)::numeric(12,2) AS "MontantTTCCalc".';


--
-- Name: COLUMN "V_Commande"."MontantRegleFactureCalc"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantRegleFactureCalc" IS 'Montant réglé enregistré sur l’en-tête, coalescé à zéro ; distinct du cumul des écritures. Expression projetée : COALESCE(c."MontantRegleFacture", 0::numeric)::numeric(12,2) AS "MontantRegleFactureCalc".';


--
-- Name: COLUMN "V_Commande"."MontantResteFactureCalc"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantResteFactureCalc" IS 'Reste enregistré sur l’en-tête, coalescé à zéro ; distinct du reste recalculé. Expression projetée : COALESCE(c."MontantResteFacture", 0::numeric)::numeric(12,2) AS "MontantResteFactureCalc".';


--
-- Name: COLUMN "V_Commande"."TotalRegleReel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."TotalRegleReel" IS 'Somme des écritures de règlement rattachées à la référence de facture, coalescée à zéro. Expression projetée : COALESCE(reg_stats."TotalRegleReel", 0::numeric)::numeric(12,2) AS "TotalRegleReel".';


--
-- Name: COLUMN "V_Commande"."ResteReel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ResteReel" IS 'Montant TTC coalescé à zéro moins le cumul réel des règlements ; le résultat peut être négatif. Expression projetée : (COALESCE(c."MontantTTC", 0::numeric) - COALESCE(reg_stats."TotalRegleReel", 0::numeric))::numeric(12,2) AS "ResteReel".';


--
-- Name: COLUMN "V_Commande"."NbReglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."NbReglements" IS 'Nombre d’écritures de règlement rattachées à la facture. Expression projetée : COALESCE(reg_stats."NbReglements", 0) AS "NbReglements".';


--
-- Name: COLUMN "V_Commande"."DernierReglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DernierReglement" IS 'Date maximale des règlements rattachés à la facture ; NULL sans règlement. Expression projetée : reg_stats."DernierReglement".';


--
-- Name: COLUMN "V_Commande"."EtatPaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EtatPaiement" IS 'Qualification de paiement de commande selon facture, montant et règlements ; reprend le montant d’en-tête en repli dans le CASE lorsque l’agrégat est absent. Expression projetée : CASE WHEN c."CodeFacture" IS NULL THEN ''Non facturée''::text WHEN COALESCE(c."MontantTTC", 0::numeric) = 0::numeric THEN ''Montant nul''::text WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", 0::numeric), 0::numeric) <= 0::numeric THEN ''Non réglée''::text WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", 0::numeric), 0::numeric) < COALESCE(c."MontantTTC", 0::numeric) THEN ''Partiellement réglée''::text WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", 0::numeric), 0::numeric) >= COALESCE(c."MontantTTC", 0::numeric) THEN ''Réglée''::text ELSE ''Indéterminé''::text END AS "EtatPaiement".';


--
-- Name: COLUMN "V_Commande"."EstPaiementEnRetard"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EstPaiementEnRetard" IS 'Vrai si échéance renseignée antérieure à CURRENT_DATE et reste positif selon l’expression de contrôle de la vue. Expression projetée : c."DateEcheancePaiement" IS NOT NULL AND c."DateEcheancePaiement"::date < CURRENT_DATE AND (COALESCE(c."MontantTTC", 0::numeric) - COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", 0::numeric), 0::numeric)) > 0::numeric AS "EstPaiementEnRetard".';


--
-- Name: COLUMN "V_Commande"."JoursAvantEcheance"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."JoursAvantEcheance" IS 'Échéance de paiement moins CURRENT_DATE, en jours ; négatif après échéance et NULL sans date. Expression projetée : CASE WHEN c."DateEcheancePaiement" IS NOT NULL THEN c."DateEcheancePaiement"::date - CURRENT_DATE ELSE NULL::integer END AS "JoursAvantEcheance".';


--
-- Name: COLUMN "V_Commande"."NbLignes"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."NbLignes" IS 'Nombre de lignes de la commande. Expression projetée : COALESCE(cd_stats."NbLignes", 0) AS "NbLignes".';


--
-- Name: COLUMN "V_Commande"."NbArticlesDistincts"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."NbArticlesDistincts" IS 'Nombre d’articles distincts dans les lignes de la commande. Expression projetée : COALESCE(cd_stats."NbArticlesDistincts", 0) AS "NbArticlesDistincts".';


--
-- Name: COLUMN "V_Commande"."QteTotale"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."QteTotale" IS 'Somme des quantités de lignes de la commande ; peut réunir différentes unités d’article et ne constitue pas un volume homogène. Expression projetée : COALESCE(cd_stats."QteTotale", 0::numeric)::numeric(14,3) AS "QteTotale".';


--
-- Name: COLUMN "V_Commande"."MontantDetails"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantDetails" IS 'Somme quantité × prix unitaire des lignes de commande ; ne calcule pas de taxe distincte. Expression projetée : COALESCE(cd_stats."MontantDetails", 0::numeric)::numeric(12,2) AS "MontantDetails".';


--
-- Name: COLUMN "V_Commande"."ListeArticles"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ListeArticles" IS 'Liste des noms d’articles distincts de la commande, séparés par une virgule et triés. Expression projetée : cd_stats."ListeArticles".';


--
-- Name: COLUMN "V_Commande"."EstCommandeSansDetails"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EstCommandeSansDetails" IS 'Vrai lorsque la commande ne possède aucune ligne. Expression projetée : COALESCE(cd_stats."NbLignes", 0) = 0 AS "EstCommandeSansDetails".';


--
-- Name: COLUMN "V_Commande"."EcartMontantDetails"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EcartMontantDetails" IS 'MontantHT de l’en-tête moins montant calculé des lignes. Expression projetée : (COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric))::numeric(12,2) AS "EcartMontantDetails".';


--
-- Name: COLUMN "V_Commande"."EstMontantIncoherent"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EstMontantIncoherent" IS 'Vrai si la valeur absolue de l’écart en-tête HT/lignes dépasse 0,01. Expression projetée : abs(COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)) > 0.01 AS "EstMontantIncoherent".';


--
-- Name: COLUMN "V_Commande"."EtatControleCommande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EtatControleCommande" IS 'Sans détails en priorité, sinon Montant incohérent si écart > 0,01 en absolu, sinon Cohérente. Expression projetée : CASE WHEN COALESCE(cd_stats."NbLignes", 0) = 0 THEN ''Sans détails''::text WHEN abs(COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)) > 0.01 THEN ''Montant incohérent''::text ELSE ''Cohérente''::text END AS "EtatControleCommande".';


--
-- Name: V_CommandeDetail; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CommandeDetail" AS
 SELECT d."ID_CmdFk",
    c."ID_Commande",
    c."DateCmd",
    c."CodeCmd",
    c."CodeFacture",
    c."ID_TypeCmdFk",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    type_cmd."NomGenerique" AS "TypeCmd",
        CASE
            WHEN ((type_cmd."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
            WHEN ((type_cmd."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
            ELSE 0
        END AS "SigneCommande",
    c."ID_StatutCmdFk",
    c."ID_StatutCmdFk" AS "ID_StatutCmd",
    statut_cmd."AbrGenerique" AS "AbrStatutCmd",
    statut_cmd."NomGenerique" AS "StatutCmd",
    d."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    (COALESCE(a."QteArticle", (0)::numeric))::numeric(14,3) AS "StockActuel",
        CASE
            WHEN ((type_cmd."AbrGenerique")::text ~~* 'sort%'::text) THEN ((COALESCE(a."QteArticle", (0)::numeric) + COALESCE(d."QteCmdDetail", (0)::numeric)))::numeric(14,3)
            WHEN ((type_cmd."AbrGenerique")::text ~~* 'entr%'::text) THEN ((COALESCE(a."QteArticle", (0)::numeric) - COALESCE(d."QteCmdDetail", (0)::numeric)))::numeric(14,3)
            ELSE (COALESCE(a."QteArticle", (0)::numeric))::numeric(14,3)
        END AS "StockAvantLigneTheorique",
    (COALESCE(d."QteCmdDetail", (0)::numeric))::numeric(14,3) AS "QteCmdDetail",
    (COALESCE(d."PUCmdDetail", (0)::numeric))::numeric(12,2) AS "PUCmdDetail",
    ((COALESCE(d."QteCmdDetail", (0)::numeric) * COALESCE(d."PUCmdDetail", (0)::numeric)))::numeric(12,2) AS "MontantLigne",
    d."ObsCmdDetail",
    d."RemiseCmdDetail",
    d."LieuCmdDetail",
    d."SelectCmdDetail",
        CASE
            WHEN ((d."QteCmdDetail" IS NULL) OR (d."QteCmdDetail" <= (0)::numeric)) THEN 'Quantité invalide'::text
            WHEN (d."PUCmdDetail" IS NULL) THEN 'Prix non renseigné'::text
            ELSE 'Valide'::text
        END AS "EtatLigne"
   FROM (((((logistique."T_CommandeDetail" d
     JOIN logistique."T_Commande" c ON ((c."ID_Commande" = d."ID_CmdFk")))
     JOIN logistique."T_Article" a ON ((a."ID_Article" = d."ID_ArticleFk")))
     LEFT JOIN referentiel."T_Generique" type_cmd ON (((c."ID_TypeCmdFk" = type_cmd."ID_Generique") AND (type_cmd."ID_CategorieGeneriqueFk" = 64))))
     LEFT JOIN referentiel."T_Generique" statut_cmd ON (((c."ID_StatutCmdFk" = statut_cmd."ID_Generique") AND (statut_cmd."ID_CategorieGeneriqueFk" = 28))))
     LEFT JOIN referentiel."T_Generique" unite ON (((a."ID_UniteFk" = unite."ID_Generique") AND (unite."ID_CategorieGeneriqueFk" = 34))));


--
-- Name: VIEW "V_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CommandeDetail" IS 'Détail au grain couple commande/article : références, quantité et prix de ligne, montant, stock actuel et stock avant ligne théorique reconstruit depuis le stock courant ; ce dernier n’est pas un instantané historique.';


--
-- Name: COLUMN "V_CommandeDetail"."ID_CmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_CmdFk" IS 'Commande à laquelle appartient la ligne. Expression projetée : d."ID_CmdFk".';


--
-- Name: COLUMN "V_CommandeDetail"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_Commande" IS 'Identifiant de la commande. Expression projetée : c."ID_Commande".';


--
-- Name: COLUMN "V_CommandeDetail"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."DateCmd" IS 'Date métier de la commande, distincte de son horodatage automatique. Expression projetée : c."DateCmd".';


--
-- Name: COLUMN "V_CommandeDetail"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."CodeCmd" IS 'Référence métier unique de la commande ; les codes C_000E et C_000S sont exclus de la vue des commandes sans lignes. Expression projetée : c."CodeCmd".';


--
-- Name: COLUMN "V_CommandeDetail"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."CodeFacture" IS 'Référence unique de la facture attachée à la commande ; utilisée pour rattacher les règlements. Expression projetée : c."CodeFacture".';


--
-- Name: COLUMN "V_CommandeDetail"."ID_TypeCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_TypeCmdFk" IS 'Type de commande dans la catégorie 64 ; son abréviation entr*/sort* détermine le sens du stock. Expression projetée : c."ID_TypeCmdFk".';


--
-- Name: COLUMN "V_CommandeDetail"."AbrTypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrTypeCmd" IS 'Abréviation du type de commande issu de la catégorie 64. Expression projetée : type_cmd."AbrGenerique" AS "AbrTypeCmd".';


--
-- Name: COLUMN "V_CommandeDetail"."TypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."TypeCmd" IS 'Libellé du type de commande issu de la catégorie 64. Expression projetée : type_cmd."NomGenerique" AS "TypeCmd".';


--
-- Name: COLUMN "V_CommandeDetail"."SigneCommande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."SigneCommande" IS 'Sens du stock d’après l’abréviation du type : +1 pour entr*, -1 pour sort*, 0 sinon. Expression projetée : CASE WHEN type_cmd."AbrGenerique"::text ~~* ''entr%''::text THEN 1 WHEN type_cmd."AbrGenerique"::text ~~* ''sort%''::text THEN ''-1''::integer ELSE 0 END AS "SigneCommande".';


--
-- Name: COLUMN "V_CommandeDetail"."ID_StatutCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_StatutCmdFk" IS 'Statut de commande dans la nomenclature de catégorie 28. Expression projetée : c."ID_StatutCmdFk".';


--
-- Name: COLUMN "V_CommandeDetail"."ID_StatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_StatutCmd" IS 'Alias de compatibilité de l’identifiant de statut de commande. Expression projetée : c."ID_StatutCmdFk" AS "ID_StatutCmd".';


--
-- Name: COLUMN "V_CommandeDetail"."AbrStatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrStatutCmd" IS 'Abréviation du statut de commande. Expression projetée : statut_cmd."AbrGenerique" AS "AbrStatutCmd".';


--
-- Name: COLUMN "V_CommandeDetail"."StatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."StatutCmd" IS 'Libellé du statut de commande. Expression projetée : statut_cmd."NomGenerique" AS "StatutCmd".';


--
-- Name: COLUMN "V_CommandeDetail"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_ArticleFk" IS 'Article rattaché à la ligne ou au mouvement. Expression projetée : d."ID_ArticleFk".';


--
-- Name: COLUMN "V_CommandeDetail"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."CodeArticleInterne" IS 'Référence interne unique de l’article. Expression projetée : a."CodeArticleInterne".';


--
-- Name: COLUMN "V_CommandeDetail"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."NomArticle" IS 'Libellé de l’article. Expression projetée : a."NomArticle".';


--
-- Name: COLUMN "V_CommandeDetail"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_UniteFk" IS 'Unité de référence de l’article, dans la nomenclature de catégorie 34. Expression projetée : a."ID_UniteFk".';


--
-- Name: COLUMN "V_CommandeDetail"."AbrUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrUnite" IS 'Abréviation de l’unité de référence de l’article. Expression projetée : unite."AbrGenerique" AS "AbrUnite".';


--
-- Name: COLUMN "V_CommandeDetail"."StockActuel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."StockActuel" IS 'Quantité courante de l’article, distincte d’un stock historique. Expression projetée : COALESCE(a."QteArticle", 0::numeric)::numeric(14,3) AS "StockActuel".';


--
-- Name: COLUMN "V_CommandeDetail"."StockAvantLigneTheorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."StockAvantLigneTheorique" IS 'Stock avant ligne reconstruit en annulant son effet sur le stock actuel ; ne représente pas un instantané enregistré. Expression projetée : CASE WHEN type_cmd."AbrGenerique"::text ~~* ''sort%''::text THEN (COALESCE(a."QteArticle", 0::numeric) + COALESCE(d."QteCmdDetail", 0::numeric))::numeric(14,3) WHEN type_cmd."AbrGenerique"::text ~~* ''entr%''::text THEN (COALESCE(a."QteArticle", 0::numeric) - COALESCE(d."QteCmdDetail", 0::numeric))::numeric(14,3) ELSE COALESCE(a."QteArticle", 0::numeric)::numeric(14,3) END AS "StockAvantLigneTheorique".';


--
-- Name: COLUMN "V_CommandeDetail"."QteCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."QteCmdDetail" IS 'Quantité de l’article sur la ligne ; les routines installées exigent une quantité strictement positive et entière pour l’impact stock. Expression projetée : COALESCE(d."QteCmdDetail", 0::numeric)::numeric(14,3) AS "QteCmdDetail".';


--
-- Name: COLUMN "V_CommandeDetail"."PUCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."PUCmdDetail" IS 'Prix unitaire propre à la ligne ; source du prix historique du mouvement de commande. Expression projetée : COALESCE(d."PUCmdDetail", 0::numeric)::numeric(12,2) AS "PUCmdDetail".';


--
-- Name: COLUMN "V_CommandeDetail"."MontantLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."MontantLigne" IS 'Quantité de ligne × prix unitaire de ligne, coalescés à zéro. Expression projetée : (COALESCE(d."QteCmdDetail", 0::numeric) * COALESCE(d."PUCmdDetail", 0::numeric))::numeric(12,2) AS "MontantLigne".';


--
-- Name: COLUMN "V_CommandeDetail"."ObsCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ObsCmdDetail" IS 'Observations enregistrées sur la ligne de commande. Expression projetée : d."ObsCmdDetail".';


--
-- Name: COLUMN "V_CommandeDetail"."RemiseCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."RemiseCmdDetail" IS 'Indicateur de remise enregistré sur la ligne ; ce booléen ne représente pas un taux de remise. Expression projetée : d."RemiseCmdDetail".';


--
-- Name: COLUMN "V_CommandeDetail"."LieuCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."LieuCmdDetail" IS 'Identifiant de lieu enregistré pour la ligne de commande ; sa signification dépend du paramétrage métier. Expression projetée : d."LieuCmdDetail".';


--
-- Name: COLUMN "V_CommandeDetail"."SelectCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."SelectCmdDetail" IS 'Indicateur de sélection enregistré sur la ligne de commande. Expression projetée : d."SelectCmdDetail".';


--
-- Name: COLUMN "V_CommandeDetail"."EtatLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."EtatLigne" IS 'Qualification : quantité invalide si absente/non positive, prix non renseigné si NULL, sinon valide ; ne remplace pas les contrôles de la routine d’écriture. Expression projetée : CASE WHEN d."QteCmdDetail" IS NULL OR d."QteCmdDetail" <= 0::numeric THEN ''Quantité invalide''::text WHEN d."PUCmdDetail" IS NULL THEN ''Prix non renseigné''::text ELSE ''Valide''::text END AS "EtatLigne".';


--
-- Name: V_CommandeOverview; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CommandeOverview" AS
 SELECT "ID_Commande",
    "DateCmd",
    "CodeCmd",
    "ID_TypeCmdFk",
    "AbrTypeCmd",
    "TypeCmd",
    "ID_StatutCmdFk",
    "AbrStatutCmd",
    "StatutCmd",
    "ID_ClientFk",
    "NomClientSaisi",
    "MontantHT",
    "MontantTTC",
    "MontantRegleFacture",
    "MontantResteFacture",
    "EtatPaiement",
    "StatusFacture",
    "DateFacture",
    "CodeFacture",
    "DateEcheancePaiement",
    "NbLignes",
    "NbArticlesDistincts",
    "QteTotale",
    "MontantDetails",
    "ListeArticles",
    "EstCommandeSansDetails",
    "EstMontantIncoherent",
    "EtatControleCommande"
   FROM logistique."V_Commande" c;


--
-- Name: VIEW "V_CommandeOverview"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CommandeOverview" IS 'Projection synthétique de V_Commande, au même grain commande, pour le suivi des lignes, montants, facturation et états de contrôle.';


--
-- Name: COLUMN "V_CommandeOverview"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."ID_Commande" IS 'Identifiant de la commande. Expression projetée : "ID_Commande".';


--
-- Name: COLUMN "V_CommandeOverview"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."DateCmd" IS 'Date métier de la commande, distincte de son horodatage automatique. Expression projetée : "DateCmd".';


--
-- Name: COLUMN "V_CommandeOverview"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."CodeCmd" IS 'Référence métier unique de la commande ; les codes C_000E et C_000S sont exclus de la vue des commandes sans lignes. Expression projetée : "CodeCmd".';


--
-- Name: COLUMN "V_CommandeOverview"."ID_TypeCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."ID_TypeCmdFk" IS 'Type de commande dans la catégorie 64 ; son abréviation entr*/sort* détermine le sens du stock. Expression projetée : "ID_TypeCmdFk".';


--
-- Name: COLUMN "V_CommandeOverview"."AbrTypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."AbrTypeCmd" IS 'Abréviation du type de commande issu de la catégorie 64. Expression projetée : "AbrTypeCmd".';


--
-- Name: COLUMN "V_CommandeOverview"."TypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."TypeCmd" IS 'Libellé du type de commande issu de la catégorie 64. Expression projetée : "TypeCmd".';


--
-- Name: COLUMN "V_CommandeOverview"."ID_StatutCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."ID_StatutCmdFk" IS 'Statut de commande dans la nomenclature de catégorie 28. Expression projetée : "ID_StatutCmdFk".';


--
-- Name: COLUMN "V_CommandeOverview"."AbrStatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."AbrStatutCmd" IS 'Abréviation du statut de commande. Expression projetée : "AbrStatutCmd".';


--
-- Name: COLUMN "V_CommandeOverview"."StatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."StatutCmd" IS 'Libellé du statut de commande. Expression projetée : "StatutCmd".';


--
-- Name: COLUMN "V_CommandeOverview"."ID_ClientFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."ID_ClientFk" IS 'Identifiant client enregistré pour l’opération ; distinct du nom client saisi librement. Expression projetée : "ID_ClientFk".';


--
-- Name: COLUMN "V_CommandeOverview"."NomClientSaisi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."NomClientSaisi" IS 'Nom du client saisi librement sur la commande, distinct d’un rattachement par identifiant. Expression projetée : "NomClientSaisi".';


--
-- Name: COLUMN "V_CommandeOverview"."MontantHT"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."MontantHT" IS 'Montant hors taxes enregistré sur la commande ; la routine actuelle de totaux le calcule depuis les lignes. Expression projetée : "MontantHT".';


--
-- Name: COLUMN "V_CommandeOverview"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."MontantTTC" IS 'Montant toutes taxes comprises enregistré sur la commande ; la routine actuelle de totaux le fixe au même montant que MontantHT, sans calcul de taxe distinct. Expression projetée : "MontantTTC".';


--
-- Name: COLUMN "V_CommandeOverview"."MontantRegleFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."MontantRegleFacture" IS 'Montant réglé enregistré sur l’en-tête de facture ; distinct de la somme des écritures de règlement. Expression projetée : "MontantRegleFacture".';


--
-- Name: COLUMN "V_CommandeOverview"."MontantResteFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."MontantResteFacture" IS 'Reste enregistré sur l’en-tête de facture ; à distinguer du reste recalculé dans les vues. Expression projetée : "MontantResteFacture".';


--
-- Name: COLUMN "V_CommandeOverview"."EtatPaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."EtatPaiement" IS 'Qualification de paiement de commande selon facture, montant et règlements ; reprend le montant d’en-tête en repli dans le CASE lorsque l’agrégat est absent. Expression projetée : "EtatPaiement".';


--
-- Name: COLUMN "V_CommandeOverview"."StatusFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."StatusFacture" IS 'Statut textuel enregistré de la facture ; le verrou SQL actuel compare exactement la valeur Clôturée. Expression projetée : "StatusFacture".';


--
-- Name: COLUMN "V_CommandeOverview"."DateFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."DateFacture" IS 'Date métier de facturation. Expression projetée : "DateFacture".';


--
-- Name: COLUMN "V_CommandeOverview"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."CodeFacture" IS 'Référence unique de la facture attachée à la commande ; utilisée pour rattacher les règlements. Expression projetée : "CodeFacture".';


--
-- Name: COLUMN "V_CommandeOverview"."DateEcheancePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."DateEcheancePaiement" IS 'Échéance de paiement de la facture ; utilisée pour les contrôles de retard. Expression projetée : "DateEcheancePaiement".';


--
-- Name: COLUMN "V_CommandeOverview"."NbLignes"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."NbLignes" IS 'Nombre de lignes de la commande. Expression projetée : "NbLignes".';


--
-- Name: COLUMN "V_CommandeOverview"."NbArticlesDistincts"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."NbArticlesDistincts" IS 'Nombre d’articles distincts dans les lignes de la commande. Expression projetée : "NbArticlesDistincts".';


--
-- Name: COLUMN "V_CommandeOverview"."QteTotale"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."QteTotale" IS 'Somme des quantités de lignes de la commande ; peut réunir différentes unités d’article et ne constitue pas un volume homogène. Expression projetée : "QteTotale".';


--
-- Name: COLUMN "V_CommandeOverview"."MontantDetails"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."MontantDetails" IS 'Somme quantité × prix unitaire des lignes de commande ; ne calcule pas de taxe distincte. Expression projetée : "MontantDetails".';


--
-- Name: COLUMN "V_CommandeOverview"."ListeArticles"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."ListeArticles" IS 'Liste des noms d’articles distincts de la commande, séparés par une virgule et triés. Expression projetée : "ListeArticles".';


--
-- Name: COLUMN "V_CommandeOverview"."EstCommandeSansDetails"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."EstCommandeSansDetails" IS 'Vrai lorsque la commande ne possède aucune ligne. Expression projetée : "EstCommandeSansDetails".';


--
-- Name: COLUMN "V_CommandeOverview"."EstMontantIncoherent"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."EstMontantIncoherent" IS 'Vrai si la valeur absolue de l’écart en-tête HT/lignes dépasse 0,01. Expression projetée : "EstMontantIncoherent".';


--
-- Name: COLUMN "V_CommandeOverview"."EtatControleCommande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."EtatControleCommande" IS 'Sans détails en priorité, sinon Montant incohérent si écart > 0,01 en absolu, sinon Cohérente. Expression projetée : "EtatControleCommande".';


--
-- Name: V_CommandesSansDetails; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CommandesSansDetails" AS
 SELECT c."ID_Commande",
    c."DateCmd",
    c."CodeCmd",
    c."ID_TypeCmdFk",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    type_cmd."NomGenerique" AS "TypeCmd",
    c."NomClientSaisi",
    c."ObsCmd"
   FROM ((logistique."T_Commande" c
     LEFT JOIN logistique."T_CommandeDetail" d ON ((d."ID_CmdFk" = c."ID_Commande")))
     LEFT JOIN referentiel."T_Generique" type_cmd ON (((c."ID_TypeCmdFk" = type_cmd."ID_Generique") AND (type_cmd."ID_CategorieGeneriqueFk" = 64))))
  WHERE ((d."ID_CmdFk" IS NULL) AND ((COALESCE(c."CodeCmd", ''::character varying))::text <> ALL (ARRAY[('C_000E'::character varying)::text, ('C_000S'::character varying)::text])));


--
-- Name: VIEW "V_CommandesSansDetails"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CommandesSansDetails" IS 'Commandes sans aucune ligne dans T_CommandeDetail ; les références C_000E et C_000S sont exclues. Grain : commande.';


--
-- Name: COLUMN "V_CommandesSansDetails"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."ID_Commande" IS 'Identifiant de la commande. Expression projetée : c."ID_Commande".';


--
-- Name: COLUMN "V_CommandesSansDetails"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."DateCmd" IS 'Date métier de la commande, distincte de son horodatage automatique. Expression projetée : c."DateCmd".';


--
-- Name: COLUMN "V_CommandesSansDetails"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."CodeCmd" IS 'Référence métier unique de la commande ; les codes C_000E et C_000S sont exclus de la vue des commandes sans lignes. Expression projetée : c."CodeCmd".';


--
-- Name: COLUMN "V_CommandesSansDetails"."ID_TypeCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."ID_TypeCmdFk" IS 'Type de commande dans la catégorie 64 ; son abréviation entr*/sort* détermine le sens du stock. Expression projetée : c."ID_TypeCmdFk".';


--
-- Name: COLUMN "V_CommandesSansDetails"."AbrTypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."AbrTypeCmd" IS 'Abréviation du type de commande issu de la catégorie 64. Expression projetée : type_cmd."AbrGenerique" AS "AbrTypeCmd".';


--
-- Name: COLUMN "V_CommandesSansDetails"."TypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."TypeCmd" IS 'Libellé du type de commande issu de la catégorie 64. Expression projetée : type_cmd."NomGenerique" AS "TypeCmd".';


--
-- Name: COLUMN "V_CommandesSansDetails"."NomClientSaisi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."NomClientSaisi" IS 'Nom du client saisi librement sur la commande, distinct d’un rattachement par identifiant. Expression projetée : c."NomClientSaisi".';


--
-- Name: COLUMN "V_CommandesSansDetails"."ObsCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."ObsCmd" IS 'Observations enregistrées sur la commande. Expression projetée : c."ObsCmd".';


--
-- Name: V_ConsoMensuelle; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_ConsoMensuelle" AS
 SELECT "ID_ArticleFk" AS "ID_Article",
    "NomArticle",
    (date_trunc('month'::text, "DateMvt"))::date AS "Mois",
    (sum(
        CASE
            WHEN ("SigneStock" = '-1'::integer) THEN COALESCE("QteMvt", 0)
            ELSE 0
        END))::numeric AS "ConsoMensuelle",
    (sum(
        CASE
            WHEN ("SigneStock" = '-1'::integer) THEN COALESCE("MontantMvt", (0)::numeric)
            ELSE (0)::numeric
        END))::numeric(14,2) AS "ValeurConsoMensuelle"
   FROM logistique."V_MouvementStock" v
  WHERE ("DateMvt" IS NOT NULL)
  GROUP BY "ID_ArticleFk", "NomArticle", ((date_trunc('month'::text, "DateMvt"))::date);


--
-- Name: VIEW "V_ConsoMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_ConsoMensuelle" IS 'Consommation au grain article/mois de DateMvt : seules les sorties de V_MouvementStock contribuent aux quantités et valeurs ; les dates absentes sont exclues.';


--
-- Name: COLUMN "V_ConsoMensuelle"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ID_Article" IS 'Identifiant de l’article. Expression projetée : "ID_ArticleFk" AS "ID_Article".';


--
-- Name: COLUMN "V_ConsoMensuelle"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."NomArticle" IS 'Libellé de l’article. Expression projetée : "NomArticle".';


--
-- Name: COLUMN "V_ConsoMensuelle"."Mois"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."Mois" IS 'Premier jour du mois de DateMvt ; clé de regroupement de consommation. Expression projetée : date_trunc(''month''::text, "DateMvt")::date AS "Mois".';


--
-- Name: COLUMN "V_ConsoMensuelle"."ConsoMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ConsoMensuelle" IS 'Somme mensuelle des quantités de sorties ; les entrées contribuent zéro. Expression projetée : sum( CASE WHEN "SigneStock" = ''-1''::integer THEN COALESCE("QteMvt", 0) ELSE 0 END)::numeric AS "ConsoMensuelle".';


--
-- Name: COLUMN "V_ConsoMensuelle"."ValeurConsoMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ValeurConsoMensuelle" IS 'Somme mensuelle des valeurs de sorties au prix historique des mouvements. Expression projetée : sum( CASE WHEN "SigneStock" = ''-1''::integer THEN COALESCE("MontantMvt", 0::numeric) ELSE 0::numeric END)::numeric(14,2) AS "ValeurConsoMensuelle".';


--
-- Name: V_CouvertureStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CouvertureStock" AS
 WITH conso AS (
         SELECT v."ID_ArticleFk",
            (sum(
                CASE
                    WHEN (v."SigneStock" = '-1'::integer) THEN COALESCE(v."QteMvt", 0)
                    ELSE 0
                END))::numeric AS conso_6m
           FROM logistique."V_MouvementStock" v
          WHERE ((v."DateMvt" >= (CURRENT_DATE - '6 mons'::interval)) AND (v."DateMvt" < (CURRENT_DATE + '1 day'::interval)))
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
     LEFT JOIN conso ON ((conso."ID_ArticleFk" = a."ID_Article")));


--
-- Name: VIEW "V_CouvertureStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CouvertureStock" IS 'Couverture au grain article : sorties depuis CURRENT_DATE moins six mois et avant le lendemain de CURRENT_DATE. Moyenne divisée par six puis stock/moyenne ; les jours futurs sont exclus, NULL sans consommation.';


--
-- Name: COLUMN "V_CouvertureStock"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."ID_Article" IS 'Identifiant de l’article. Expression projetée : a."ID_Article".';


--
-- Name: COLUMN "V_CouvertureStock"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."CodeArticleInterne" IS 'Référence interne unique de l’article. Expression projetée : a."CodeArticleInterne".';


--
-- Name: COLUMN "V_CouvertureStock"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."NomArticle" IS 'Libellé de l’article. Expression projetée : a."NomArticle".';


--
-- Name: COLUMN "V_CouvertureStock"."AbrUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."AbrUnite" IS 'Abréviation de l’unité de référence de l’article. Expression projetée : a."AbrUnite".';


--
-- Name: COLUMN "V_CouvertureStock"."StockActuel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."StockActuel" IS 'Quantité courante de l’article, distincte d’un stock historique. Expression projetée : a."QteArticle" AS "StockActuel".';


--
-- Name: COLUMN "V_CouvertureStock"."Conso6Mois"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."Conso6Mois" IS 'Quantités de sorties du début glissant à six mois inclus au lendemain du jour courant exclu ; les mouvements datés d’un jour futur ne contribuent pas. Expression : COALESCE(conso.conso_6m, 0::numeric).';


--
-- Name: COLUMN "V_CouvertureStock"."ConsoMoyMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."ConsoMoyMensuelle" IS 'Consommation retenue divisée par six, arrondie à deux décimales ; pas une moyenne sur le nombre de mois effectivement observés. Expression projetée : round(COALESCE(conso.conso_6m, 0::numeric) / 6.0, 2) AS "ConsoMoyMensuelle".';


--
-- Name: COLUMN "V_CouvertureStock"."CouvertureMois"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."CouvertureMois" IS 'Stock actuel divisé par la consommation mensuelle moyenne, arrondi à un chiffre ; NULL si aucune consommation. Expression projetée : CASE WHEN COALESCE(conso.conso_6m, 0::numeric) = 0::numeric THEN NULL::numeric ELSE round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1) END AS "CouvertureMois".';


--
-- Name: COLUMN "V_CouvertureStock"."EtatCouverture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."EtatCouverture" IS 'Aucune consommation récente si consommation nulle, Critique sous un mois, Faible sous trois mois, sinon Correcte, sur le ratio arrondi. Expression projetée : CASE WHEN COALESCE(conso.conso_6m, 0::numeric) = 0::numeric THEN ''Aucune consommation récente''::text WHEN round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1) < 1::numeric THEN ''Critique''::text WHEN round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1) < 3::numeric THEN ''Faible''::text ELSE ''Correcte''::text END AS "EtatCouverture".';


--
-- Name: V_Mouvement; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Mouvement" AS
 SELECT m."DateHeureAutoMvt",
    m."DateMvt",
    m."ID_Mvt",
    m."ID_TypeMvtFk",
    g_typemvt."AbrGenerique" AS "TypeMvt",
    g_typemvt."NomGenerique" AS "NomTypeMvt",
    m."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    m."ID_cmdFk",
    c."CodeCmd",
    c."DateCmd",
    COALESCE(m."QteMvt", 0) AS "QteMvt",
    (COALESCE(m."PUMvt", (0)::numeric))::numeric(12,2) AS "PUMvt",
        CASE
            WHEN ((g_typemvt."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
            WHEN ((g_typemvt."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
            ELSE 0
        END AS "SigneStock",
    ((COALESCE(m."QteMvt", 0) *
        CASE
            WHEN ((g_typemvt."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
            WHEN ((g_typemvt."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
            ELSE 0
        END))::numeric AS "QteMvtSigned",
    (((COALESCE(m."QteMvt", 0))::numeric * COALESCE(m."PUMvt", (0)::numeric)))::numeric(14,2) AS "MontantMvt",
        CASE
            WHEN (m."ID_cmdFk" IS NULL) THEN 'Ajustement direct article'::text
            ELSE 'Commande'::text
        END AS "OrigineMouvement"
   FROM (((logistique."T_Mouvement" m
     LEFT JOIN logistique."T_Article" a ON ((m."ID_ArticleFk" = a."ID_Article")))
     LEFT JOIN logistique."T_Commande" c ON ((m."ID_cmdFk" = c."ID_Commande")))
     LEFT JOIN referentiel."T_Generique" g_typemvt ON (((m."ID_TypeMvtFk" = g_typemvt."ID_Generique") AND (g_typemvt."ID_CategorieGeneriqueFk" = 64))));


--
-- Name: VIEW "V_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Mouvement" IS 'Historique enrichi au grain mouvement : article, commande, type historique, quantité, signe, prix et origine. TypeMvt contient ici l’abréviation ; les ajustements directs ont une commande NULL.';


--
-- Name: COLUMN "V_Mouvement"."DateHeureAutoMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."DateHeureAutoMvt" IS 'Horodatage automatique de création du mouvement, sans fuseau dans le type SQL. Expression projetée : m."DateHeureAutoMvt".';


--
-- Name: COLUMN "V_Mouvement"."DateMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."DateMvt" IS 'Date métier du mouvement, utilisée dans les consommations et audits de stock. Expression projetée : m."DateMvt".';


--
-- Name: COLUMN "V_Mouvement"."ID_Mvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."ID_Mvt" IS 'Identifiant du mouvement de stock. Expression projetée : m."ID_Mvt".';


--
-- Name: COLUMN "V_Mouvement"."ID_TypeMvtFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."ID_TypeMvtFk" IS 'Type historique du mouvement dans la catégorie 64 ; son abréviation détermine son signe de stock. Expression projetée : m."ID_TypeMvtFk".';


--
-- Name: COLUMN "V_Mouvement"."TypeMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."TypeMvt" IS 'Abréviation du type historique de mouvement, issue de AbrGenerique ; distincte du libellé complet NomTypeMvt. Expression projetée : g_typemvt."AbrGenerique" AS "TypeMvt".';


--
-- Name: COLUMN "V_Mouvement"."NomTypeMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."NomTypeMvt" IS 'Libellé complet du type de mouvement. Expression projetée : g_typemvt."NomGenerique" AS "NomTypeMvt".';


--
-- Name: COLUMN "V_Mouvement"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."ID_ArticleFk" IS 'Article rattaché à la ligne ou au mouvement. Expression projetée : m."ID_ArticleFk".';


--
-- Name: COLUMN "V_Mouvement"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."CodeArticleInterne" IS 'Référence interne unique de l’article. Expression projetée : a."CodeArticleInterne".';


--
-- Name: COLUMN "V_Mouvement"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."NomArticle" IS 'Libellé de l’article. Expression projetée : a."NomArticle".';


--
-- Name: COLUMN "V_Mouvement"."ID_cmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."ID_cmdFk" IS 'Commande source du mouvement ; NULL pour un ajustement direct d’article. Expression projetée : m."ID_cmdFk".';


--
-- Name: COLUMN "V_Mouvement"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."CodeCmd" IS 'Référence métier unique de la commande ; les codes C_000E et C_000S sont exclus de la vue des commandes sans lignes. Expression projetée : c."CodeCmd".';


--
-- Name: COLUMN "V_Mouvement"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."DateCmd" IS 'Date métier de la commande, distincte de son horodatage automatique. Expression projetée : c."DateCmd".';


--
-- Name: COLUMN "V_Mouvement"."QteMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."QteMvt" IS 'Quantité entière du mouvement ; le signe entrée/sortie vient du type de mouvement, pas du signe de cette quantité. Expression projetée : COALESCE(m."QteMvt", 0) AS "QteMvt".';


--
-- Name: COLUMN "V_Mouvement"."PUMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."PUMvt" IS 'Prix unitaire historique du mouvement : prix de ligne pour une commande, prix de vente article pour l’ajustement direct produit par le trigger actuel. Expression projetée : COALESCE(m."PUMvt", 0::numeric)::numeric(12,2) AS "PUMvt".';


--
-- Name: COLUMN "V_Mouvement"."SigneStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."SigneStock" IS 'Signe du type historique : +1 pour entr*, -1 pour sort*, 0 sinon ; indépendant du type actuel de commande. Expression projetée : CASE WHEN g_typemvt."AbrGenerique"::text ~~* ''entr%''::text THEN 1 WHEN g_typemvt."AbrGenerique"::text ~~* ''sort%''::text THEN ''-1''::integer ELSE 0 END AS "SigneStock".';


--
-- Name: COLUMN "V_Mouvement"."QteMvtSigned"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."QteMvtSigned" IS 'Quantité de mouvement multipliée par le signe du type historique. Expression projetée : (COALESCE(m."QteMvt", 0) * CASE WHEN g_typemvt."AbrGenerique"::text ~~* ''entr%''::text THEN 1 WHEN g_typemvt."AbrGenerique"::text ~~* ''sort%''::text THEN ''-1''::integer ELSE 0 END)::numeric AS "QteMvtSigned".';


--
-- Name: COLUMN "V_Mouvement"."MontantMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."MontantMvt" IS 'Quantité × prix unitaire historique du mouvement. Expression projetée : (COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric))::numeric(14,2) AS "MontantMvt".';


--
-- Name: COLUMN "V_Mouvement"."OrigineMouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."OrigineMouvement" IS 'Commande si ID_cmdFk est renseigné, sinon Ajustement direct article. Expression projetée : CASE WHEN m."ID_cmdFk" IS NULL THEN ''Ajustement direct article''::text ELSE ''Commande''::text END AS "OrigineMouvement".';


--
-- Name: V_SuiviReglements; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_SuiviReglements" AS
 SELECT c."ID_Commande",
    c."CodeCmd",
    c."CodeFacture",
    c."DateFacture",
    c."DateEcheancePaiement",
    c."NomClientSaisi",
    (COALESCE(c."MontantTTC", (0)::numeric))::numeric(12,2) AS "MontantTTC",
    (COALESCE(sum(r."MontantRegle"), (0)::numeric))::numeric(12,2) AS "TotalRegle",
    ((COALESCE(c."MontantTTC", (0)::numeric) - COALESCE(sum(r."MontantRegle"), (0)::numeric)))::numeric(12,2) AS "Reste",
    count(r."ID_Reglement") AS "NbReglements",
    max(r."DateReglement") AS "DernierReglement",
        CASE
            WHEN (c."CodeFacture" IS NULL) THEN 'Non facturée'::text
            WHEN (COALESCE(c."MontantTTC", (0)::numeric) = (0)::numeric) THEN 'Montant nul'::text
            WHEN (COALESCE(sum(r."MontantRegle"), (0)::numeric) <= (0)::numeric) THEN 'Non réglée'::text
            WHEN (COALESCE(sum(r."MontantRegle"), (0)::numeric) < COALESCE(c."MontantTTC", (0)::numeric)) THEN 'Partiellement réglée'::text
            ELSE 'Réglée'::text
        END AS "EtatReglement",
    ((c."DateEcheancePaiement" IS NOT NULL) AND ((c."DateEcheancePaiement")::date < CURRENT_DATE) AND ((COALESCE(c."MontantTTC", (0)::numeric) - COALESCE(sum(r."MontantRegle"), (0)::numeric)) > (0)::numeric)) AS "EstEnRetard",
        CASE
            WHEN (c."DateEcheancePaiement" IS NOT NULL) THEN ((c."DateEcheancePaiement")::date - CURRENT_DATE)
            ELSE NULL::integer
        END AS "JoursAvantEcheance"
   FROM (logistique."T_Commande" c
     LEFT JOIN logistique."T_Reglements" r ON (((r."CodeFactureFk")::text = (c."CodeFacture")::text)))
  GROUP BY c."ID_Commande", c."CodeCmd", c."CodeFacture", c."DateFacture", c."DateEcheancePaiement", c."NomClientSaisi", c."MontantTTC";


--
-- Name: VIEW "V_SuiviReglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_SuiviReglements" IS 'Suivi au grain commande/facture : somme des règlements rattachés par CodeFactureFk, reste TTC moins total réglé, dernière date et retard. Inclut aussi les commandes non facturées.';


--
-- Name: COLUMN "V_SuiviReglements"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."ID_Commande" IS 'Identifiant de la commande. Expression projetée : c."ID_Commande".';


--
-- Name: COLUMN "V_SuiviReglements"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."CodeCmd" IS 'Référence métier unique de la commande ; les codes C_000E et C_000S sont exclus de la vue des commandes sans lignes. Expression projetée : c."CodeCmd".';


--
-- Name: COLUMN "V_SuiviReglements"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."CodeFacture" IS 'Référence unique de la facture attachée à la commande ; utilisée pour rattacher les règlements. Expression projetée : c."CodeFacture".';


--
-- Name: COLUMN "V_SuiviReglements"."DateFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."DateFacture" IS 'Date métier de facturation. Expression projetée : c."DateFacture".';


--
-- Name: COLUMN "V_SuiviReglements"."DateEcheancePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."DateEcheancePaiement" IS 'Échéance de paiement de la facture ; utilisée pour les contrôles de retard. Expression projetée : c."DateEcheancePaiement".';


--
-- Name: COLUMN "V_SuiviReglements"."NomClientSaisi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."NomClientSaisi" IS 'Nom du client saisi librement sur la commande, distinct d’un rattachement par identifiant. Expression projetée : c."NomClientSaisi".';


--
-- Name: COLUMN "V_SuiviReglements"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantTTC" IS 'Montant toutes taxes comprises enregistré sur la commande ; la routine actuelle de totaux le fixe au même montant que MontantHT, sans calcul de taxe distinct. Expression projetée : COALESCE(c."MontantTTC", 0::numeric)::numeric(12,2) AS "MontantTTC".';


--
-- Name: COLUMN "V_SuiviReglements"."TotalRegle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."TotalRegle" IS 'Cumul des montants des écritures rattachées à la facture ; absence ramenée à zéro dans la vue. Expression projetée : COALESCE(sum(r."MontantRegle"), 0::numeric)::numeric(12,2) AS "TotalRegle".';


--
-- Name: COLUMN "V_SuiviReglements"."Reste"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."Reste" IS 'Montant TTC de commande moins total des règlements ; peut être négatif. Expression projetée : (COALESCE(c."MontantTTC", 0::numeric) - COALESCE(sum(r."MontantRegle"), 0::numeric))::numeric(12,2) AS "Reste".';


--
-- Name: COLUMN "V_SuiviReglements"."NbReglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."NbReglements" IS 'Nombre d’écritures de règlement rattachées à la facture. Expression projetée : count(r."ID_Reglement") AS "NbReglements".';


--
-- Name: COLUMN "V_SuiviReglements"."DernierReglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."DernierReglement" IS 'Date maximale des règlements rattachés à la facture ; NULL sans règlement. Expression projetée : max(r."DateReglement") AS "DernierReglement".';


--
-- Name: COLUMN "V_SuiviReglements"."EtatReglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."EtatReglement" IS 'Qualification du règlement de facture à partir de la référence, du montant TTC et du cumul des écritures. Expression projetée : CASE WHEN c."CodeFacture" IS NULL THEN ''Non facturée''::text WHEN COALESCE(c."MontantTTC", 0::numeric) = 0::numeric THEN ''Montant nul''::text WHEN COALESCE(sum(r."MontantRegle"), 0::numeric) <= 0::numeric THEN ''Non réglée''::text WHEN COALESCE(sum(r."MontantRegle"), 0::numeric) < COALESCE(c."MontantTTC", 0::numeric) THEN ''Partiellement réglée''::text ELSE ''Réglée''::text END AS "EtatReglement".';


--
-- Name: COLUMN "V_SuiviReglements"."EstEnRetard"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."EstEnRetard" IS 'Vrai si échéance antérieure à CURRENT_DATE et reste TTC/règlements positif. Expression projetée : c."DateEcheancePaiement" IS NOT NULL AND c."DateEcheancePaiement"::date < CURRENT_DATE AND (COALESCE(c."MontantTTC", 0::numeric) - COALESCE(sum(r."MontantRegle"), 0::numeric)) > 0::numeric AS "EstEnRetard".';


--
-- Name: COLUMN "V_SuiviReglements"."JoursAvantEcheance"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."JoursAvantEcheance" IS 'Échéance de paiement moins CURRENT_DATE, en jours ; négatif après échéance et NULL sans date. Expression projetée : CASE WHEN c."DateEcheancePaiement" IS NOT NULL THEN c."DateEcheancePaiement"::date - CURRENT_DATE ELSE NULL::integer END AS "JoursAvantEcheance".';


--
-- Name: T_Caisse; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Caisse" (
    "IdCaisse" integer CONSTRAINT "T_Caisse_IdCaisse_not_null" NOT NULL,
    "IdDeviseFk" integer CONSTRAINT "T_Caisse_IdDeviseFk_not_null" NOT NULL,
    "MontantCaisse" numeric(10,2) DEFAULT 0,
    "IdEntiteFk" integer
);


--
-- Name: TABLE "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Caisse" IS 'Solde courant de caisse par entité et devise ; unicité du couple IdEntiteFk/IdDeviseFk. Mis à jour par les effets des paiements éligibles dans la fonction de gestion de caisse.';


--
-- Name: COLUMN "T_Caisse"."IdCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdCaisse" IS 'Identifiant de la caisse.';


--
-- Name: COLUMN "T_Caisse"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts. Relation imposée : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Caisse"."MontantCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."MontantCaisse" IS 'Solde courant enregistré de cette caisse, dans sa devise ; à rapprocher du solde théorique des paiements.';


--
-- Name: COLUMN "T_Caisse"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: CONSTRAINT "T_Caisse_IdCaisse_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdCaisse_not_null" ON operations."T_Caisse" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Caisse". Définition : NOT NULL "IdCaisse".';


--
-- Name: CONSTRAINT "T_Caisse_IdDeviseFk_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdDeviseFk_not_null" ON operations."T_Caisse" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Caisse". Définition : NOT NULL "IdDeviseFk".';


--
-- Name: T_Caisse_IdCaisse_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Caisse" ALTER COLUMN "IdCaisse" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Caisse_IdCaisse_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Caisse_IdCaisse_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Caisse_IdCaisse_seq" IS 'Séquence de génération de "operations"."T_Caisse"."IdCaisse". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Paiement; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Paiement" (
    "IdPaiement" integer CONSTRAINT "T_Paiement_IdPaiement_not_null" NOT NULL,
    "CodePaiement" character varying(25),
    "IdUserFk" integer CONSTRAINT "T_Paiement_IdUserFk_not_null" NOT NULL,
    "IdTypePaiementFk" integer CONSTRAINT "T_Paiement_IdTypePaiementFk_not_null" NOT NULL,
    "MontantPaiement" numeric(10,2) CONSTRAINT "T_Paiement_MontantPaiement_not_null" NOT NULL,
    "IdStatutPaiementFk" integer,
    "DatePaiement" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "ObsPaiement" text,
    "ValidePaiement" boolean DEFAULT true CONSTRAINT "T_Paiement_ValidePaiement_not_null" NOT NULL,
    "IdDeviseFk" integer CONSTRAINT "T_Paiement_IdDeviseFk_not_null" NOT NULL,
    "IdPayeurFk" integer,
    "IdTypeMouvementFk" integer,
    "IdEntiteFk" integer CONSTRAINT "T_Paiement_IdEntiteFk_not_null" NOT NULL,
    CONSTRAINT chk_montant_paiement CHECK (("MontantPaiement" > (0)::numeric))
);


--
-- Name: TABLE "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Paiement" IS 'Paiements actifs avec montant, devise, statut, sens de mouvement, utilisateur et entité. Les triggers gèrent caisse, audit, notification et déplacement des paiements de plus de deux ans vers les archives.';


--
-- Name: COLUMN "T_Paiement"."IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdPaiement" IS 'Identifiant du paiement ; conservé depuis le paiement source dans la table d’archives.';


--
-- Name: COLUMN "T_Paiement"."CodePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."CodePaiement" IS 'Référence métier du paiement.';


--
-- Name: COLUMN "T_Paiement"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Paiement"."IdTypePaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdTypePaiementFk" IS 'Type métier du paiement dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Paiement"."MontantPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."MontantPaiement" IS 'Montant du paiement dans IdDeviseFk ; strictement positif sur T_Paiement.';


--
-- Name: COLUMN "T_Paiement"."IdStatutPaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdStatutPaiementFk" IS 'Statut de paiement dans le référentiel ; les règles de caisse et d’audit déterminent les statuts retenus.';


--
-- Name: COLUMN "T_Paiement"."DatePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."DatePaiement" IS 'Date et heure du paiement ; sert aux regroupements de flux et à l’archivage.';


--
-- Name: COLUMN "T_Paiement"."ObsPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ObsPaiement" IS 'Observations enregistrées sur le paiement.';


--
-- Name: COLUMN "T_Paiement"."ValidePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ValidePaiement" IS 'Indique si le paiement est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Paiement"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts. Relation imposée : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Paiement"."IdPayeurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdPayeurFk" IS 'Payeur enregistré pour le paiement. Relation imposée : FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Paiement"."IdTypeMouvementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdTypeMouvementFk" IS 'Sens/type du mouvement de paiement dans le référentiel ; distinct du type de mouvement de stock.';


--
-- Name: COLUMN "T_Paiement"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: CONSTRAINT "T_Paiement_IdPaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdPaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdPaiement".';


--
-- Name: CONSTRAINT "T_Paiement_IdUserFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdUserFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdUserFk".';


--
-- Name: CONSTRAINT "T_Paiement_IdTypePaiementFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdTypePaiementFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdTypePaiementFk".';


--
-- Name: CONSTRAINT "T_Paiement_MontantPaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_MontantPaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "MontantPaiement".';


--
-- Name: CONSTRAINT "T_Paiement_ValidePaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_ValidePaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "ValidePaiement".';


--
-- Name: CONSTRAINT "T_Paiement_IdDeviseFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdDeviseFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdDeviseFk".';


--
-- Name: CONSTRAINT "T_Paiement_IdEntiteFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdEntiteFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdEntiteFk".';


--
-- Name: CONSTRAINT chk_montant_paiement ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT chk_montant_paiement ON operations."T_Paiement" IS 'Contrôle de cohérence des valeurs autorisées dans "operations"."T_Paiement". Définition : CHECK ("MontantPaiement" > 0::numeric).';


--
-- Name: T_Paiement_Archive; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Paiement_Archive" (
    "IdPaiement" integer,
    "CodePaiement" character varying(25),
    "IdUserFk" integer,
    "IdTypePaiementFk" integer,
    "MontantPaiement" numeric(10,2),
    "IdStatutPaiementFk" integer,
    "DatePaiement" timestamp with time zone,
    "ObsPaiement" text,
    "ValidePaiement" boolean,
    "IdDeviseFk" integer,
    "IdPayeurFk" integer,
    "IdTypeMouvementFk" integer,
    "DateArchivage" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "IdEntiteFk" integer,
    "IdPaiementArchive" integer CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" NOT NULL
);


--
-- Name: TABLE "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Paiement_Archive" IS 'Archive des paiements déplacés depuis T_Paiement, avec identifiant du paiement source, identifiant propre d’archive et date d’archivage. Utilisée avec les paiements actifs par le contrôle de caisse.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPaiement" IS 'Identifiant du paiement ; conservé depuis le paiement source dans la table d’archives.';


--
-- Name: COLUMN "T_Paiement_Archive"."CodePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."CodePaiement" IS 'Référence métier du paiement.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdTypePaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdTypePaiementFk" IS 'Type métier du paiement dans le référentiel.';


--
-- Name: COLUMN "T_Paiement_Archive"."MontantPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."MontantPaiement" IS 'Montant du paiement dans IdDeviseFk ; strictement positif sur T_Paiement.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdStatutPaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdStatutPaiementFk" IS 'Statut de paiement dans le référentiel ; les règles de caisse et d’audit déterminent les statuts retenus.';


--
-- Name: COLUMN "T_Paiement_Archive"."DatePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."DatePaiement" IS 'Date et heure du paiement ; sert aux regroupements de flux et à l’archivage.';


--
-- Name: COLUMN "T_Paiement_Archive"."ObsPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."ObsPaiement" IS 'Observations enregistrées sur le paiement.';


--
-- Name: COLUMN "T_Paiement_Archive"."ValidePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."ValidePaiement" IS 'Indique si le paiement est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdPayeurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPayeurFk" IS 'Payeur enregistré pour le paiement.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdTypeMouvementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdTypeMouvementFk" IS 'Sens/type du mouvement de paiement dans le référentiel ; distinct du type de mouvement de stock.';


--
-- Name: COLUMN "T_Paiement_Archive"."DateArchivage"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."DateArchivage" IS 'Horodatage du déplacement du paiement vers les archives.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Paiement_Archive"."IdPaiementArchive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPaiementArchive" IS 'Identifiant propre de la ligne d’archive du paiement.';


--
-- Name: CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" ON operations."T_Paiement_Archive" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement_Archive". Définition : NOT NULL "IdPaiementArchive".';


--
-- Name: T_Paiement_Archive_IdPaiementArchive_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Paiement_Archive" ALTER COLUMN "IdPaiementArchive" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Paiement_Archive_IdPaiementArchive_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Paiement_Archive_IdPaiementArchive_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Paiement_Archive_IdPaiementArchive_seq" IS 'Séquence de génération de "operations"."T_Paiement_Archive"."IdPaiementArchive". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Paiement_IdPaiement_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Paiement" ALTER COLUMN "IdPaiement" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Paiement_IdPaiement_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Paiement_IdPaiement_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Paiement_IdPaiement_seq" IS 'Séquence de génération de "operations"."T_Paiement"."IdPaiement". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Professionnel; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_Professionnel" (
    "IdProfessionnel" integer CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" NOT NULL,
    "IdUserFk" integer CONSTRAINT "T_Professionnel_IdUserFk_not_null" NOT NULL,
    "IdTypeProfessionnelFk" integer CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" NOT NULL,
    "IdSpecialiteFk" integer CONSTRAINT "T_Professionnel_IdSpecialiteFk_not_null" NOT NULL,
    "NumeroIdentification" character varying(50),
    "ExperienceAns" integer,
    "ObsProfessionnel" text,
    "ValideProfessionnel" boolean DEFAULT true,
    CONSTRAINT "Chk_Prof_Experience_NonNegative" CHECK ((("ExperienceAns" IS NULL) OR ("ExperienceAns" >= 0))),
    CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" CHECK ((("NumeroIdentification" IS NULL) OR (length(TRIM(BOTH FROM "NumeroIdentification")) > 0)))
);


--
-- Name: TABLE "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_Professionnel" IS 'Profil professionnel lié à un utilisateur, avec type, spécialité, identification, expérience et validité.';


--
-- Name: COLUMN "T_Professionnel"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdProfessionnel" IS 'Identifiant du profil professionnel.';


--
-- Name: COLUMN "T_Professionnel"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "T_Professionnel"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "T_Professionnel"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdSpecialiteFk" IS 'Spécialité du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "T_Professionnel"."NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."NumeroIdentification" IS 'Numéro d’identification professionnel déclaré ; une chaîne vide est interdite si renseigné.';


--
-- Name: COLUMN "T_Professionnel"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ExperienceAns" IS 'Nombre d’années d’expérience déclaré pour le professionnel ; valeur négative interdite.';


--
-- Name: COLUMN "T_Professionnel"."ObsProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ObsProfessionnel" IS 'Observations enregistrées sur le profil professionnel.';


--
-- Name: COLUMN "T_Professionnel"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ValideProfessionnel" IS 'Indique si le profil professionnel est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdProfessionnel".';


--
-- Name: CONSTRAINT "T_Professionnel_IdUserFk_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdUserFk_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdUserFk".';


--
-- Name: CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdTypeProfessionnelFk".';


--
-- Name: CONSTRAINT "T_Professionnel_IdSpecialiteFk_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdSpecialiteFk_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdSpecialiteFk".';


--
-- Name: CONSTRAINT "Chk_Prof_Experience_NonNegative" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_Prof_Experience_NonNegative" ON professionnel."T_Professionnel" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel". Définition : CHECK ("ExperienceAns" IS NULL OR "ExperienceAns" >= 0).';


--
-- Name: CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" ON professionnel."T_Professionnel" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel". Définition : CHECK ("NumeroIdentification" IS NULL OR length(TRIM(BOTH FROM "NumeroIdentification")) > 0).';


--
-- Name: T_Professionnel_Entite; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_Professionnel_Entite" (
    "IdProfessionnelFk" integer CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" NOT NULL,
    "IdTypeLienFk" integer,
    "DateDebut" timestamp without time zone,
    "DateFin" timestamp without time zone,
    "EstPrincipal" boolean DEFAULT false,
    "ObsLien" text,
    CONSTRAINT "Chk_ProfEnt_Period" CHECK ((("DateFin" IS NULL) OR ("DateDebut" IS NULL) OR ("DateFin" >= "DateDebut")))
);


--
-- Name: TABLE "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_Professionnel_Entite" IS 'Rattachement d’un professionnel à une entité, identifié par leur couple, avec type de lien, période et indicateur de lien principal.';


--
-- Name: COLUMN "T_Professionnel_Entite"."IdProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdProfessionnelFk" IS 'Professionnel rattaché à la discussion ou à l’entité. Relation imposée : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: COLUMN "T_Professionnel_Entite"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "T_Professionnel_Entite"."IdTypeLienFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdTypeLienFk" IS 'Type de relation entre professionnel et entité. Relation imposée : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "T_Professionnel_Entite"."DateDebut"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."DateDebut" IS 'Début du rattachement professionnel à l’entité.';


--
-- Name: COLUMN "T_Professionnel_Entite"."DateFin"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."DateFin" IS 'Fin éventuelle du rattachement ; ne peut précéder DateDebut lorsque les deux dates sont renseignées.';


--
-- Name: COLUMN "T_Professionnel_Entite"."EstPrincipal"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."EstPrincipal" IS 'Indique si ce rattachement professionnel est marqué comme principal.';


--
-- Name: COLUMN "T_Professionnel_Entite"."ObsLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."ObsLien" IS 'Observations enregistrées sur le rattachement professionnel.';


--
-- Name: CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" ON professionnel."T_Professionnel_Entite" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel_Entite". Définition : NOT NULL "IdProfessionnelFk".';


--
-- Name: CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" ON professionnel."T_Professionnel_Entite" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel_Entite". Définition : NOT NULL "IdEntiteFk".';


--
-- Name: CONSTRAINT "Chk_ProfEnt_Period" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_ProfEnt_Period" ON professionnel."T_Professionnel_Entite" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel_Entite". Définition : CHECK ("DateFin" IS NULL OR "DateDebut" IS NULL OR "DateFin" >= "DateDebut").';


--
-- Name: T_Professionnel_IdProfessionnel_seq; Type: SEQUENCE; Schema: professionnel; Owner: -
--

ALTER TABLE professionnel."T_Professionnel" ALTER COLUMN "IdProfessionnel" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME professionnel."T_Professionnel_IdProfessionnel_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Professionnel_IdProfessionnel_seq"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON SEQUENCE professionnel."T_Professionnel_IdProfessionnel_seq" IS 'Séquence de génération de "professionnel"."T_Professionnel"."IdProfessionnel". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: V_Professionnel_Detail; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Detail" AS
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
   FROM (((professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     LEFT JOIN referentiel."T_Generique" tp ON ((tp."ID_Generique" = p."IdTypeProfessionnelFk")))
     LEFT JOIN referentiel."T_Generique" sp ON ((sp."ID_Generique" = p."IdSpecialiteFk")));


--
-- Name: VIEW "V_Professionnel_Detail"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Detail" IS 'Annuaire administratif au grain professionnel, avec coordonnées personnelles : réservé aux permissions administratives explicites.';


--
-- Name: COLUMN "V_Professionnel_Detail"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."IdProfessionnel" IS 'Identifiant du profil professionnel.';


--
-- Name: COLUMN "V_Professionnel_Detail"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Detail"."NomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."NomUser" IS 'Nom de l’utilisateur.';


--
-- Name: COLUMN "V_Professionnel_Detail"."PrenomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."PrenomUser" IS 'Prénom de l’utilisateur.';


--
-- Name: COLUMN "V_Professionnel_Detail"."EmailUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';


--
-- Name: COLUMN "V_Professionnel_Detail"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Detail"."TypeProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."TypeProfessionnel" IS 'Projection SQL de TypeProfessionnel ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Detail"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."IdSpecialiteFk" IS 'Spécialité du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Detail"."Specialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."Specialite" IS 'Projection SQL de Specialite ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Detail"."NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."NumeroIdentification" IS 'Numéro d’identification professionnel déclaré ; une chaîne vide est interdite si renseigné.';


--
-- Name: COLUMN "V_Professionnel_Detail"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."ExperienceAns" IS 'Nombre d’années d’expérience déclaré pour le professionnel ; valeur négative interdite.';


--
-- Name: COLUMN "V_Professionnel_Detail"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."ValideProfessionnel" IS 'Indique si le profil professionnel est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "V_Professionnel_Detail"."PhoneUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."PhoneUser" IS 'Téléphone utilisateur ; le trigger de normalisation conserve les chiffres sans interpréter le pays.';


--
-- Name: COLUMN "V_Professionnel_Detail"."SexeUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."SexeUser" IS 'Code de sexe enregistré pour le compte ; la contrainte actuelle admet M ou F.';


--
-- Name: COLUMN "V_Professionnel_Detail"."UrlPhoto"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Detail"."UrlPhoto" IS 'Référence de la photo de l’utilisateur.';


--
-- Name: T_Entite_Localisation; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Entite_Localisation" (
    "IdEntiteLocalisation" integer CONSTRAINT "T_Entite_Localisation_IdEntiteLocalisation_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Entite_Localisation_IdEntiteFk_not_null" NOT NULL,
    "IdNiveau_3_Fk" integer,
    "IdNiveau_4_Fk" integer,
    "IdNiveau_5_Fk" integer,
    "Latitude" numeric(9,6),
    "Longitude" numeric(9,6),
    "AdresseDetaillee" text,
    "DateCreation" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Entite_Localisation" IS 'Localisations des entités : niveaux géographiques de rattachement, coordonnées et adresse détaillée. Une entité peut posséder plusieurs localisations.';


--
-- Name: COLUMN "T_Entite_Localisation"."IdEntiteLocalisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdEntiteLocalisation" IS 'Identifiant de la localisation d’entité.';


--
-- Name: COLUMN "T_Entite_Localisation"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: COLUMN "T_Entite_Localisation"."IdNiveau_3_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdNiveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Relation imposée : FOREIGN KEY ("IdNiveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3").';


--
-- Name: COLUMN "T_Entite_Localisation"."IdNiveau_4_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdNiveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Relation imposée : FOREIGN KEY ("IdNiveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4").';


--
-- Name: COLUMN "T_Entite_Localisation"."IdNiveau_5_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdNiveau_5_Fk" IS 'Unité géographique de rattachement de niveau 5. Relation imposée : FOREIGN KEY ("IdNiveau_5_Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5").';


--
-- Name: COLUMN "T_Entite_Localisation"."Latitude"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."Latitude" IS 'Latitude de la localisation ; coordonnée décimale.';


--
-- Name: COLUMN "T_Entite_Localisation"."Longitude"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."Longitude" IS 'Longitude de la localisation ; coordonnée décimale.';


--
-- Name: COLUMN "T_Entite_Localisation"."AdresseDetaillee"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."AdresseDetaillee" IS 'Adresse détaillée de cette localisation.';


--
-- Name: COLUMN "T_Entite_Localisation"."DateCreation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."DateCreation" IS 'Horodatage de création de la localisation, sans fuseau dans le type SQL.';


--
-- Name: CONSTRAINT "T_Entite_Localisation_IdEntiteLocalisation_not_null" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_Localisation_IdEntiteLocalisation_not_null" ON systeme."T_Entite_Localisation" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite_Localisation". Définition : NOT NULL "IdEntiteLocalisation".';


--
-- Name: CONSTRAINT "T_Entite_Localisation_IdEntiteFk_not_null" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_Localisation_IdEntiteFk_not_null" ON systeme."T_Entite_Localisation" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite_Localisation". Définition : NOT NULL "IdEntiteFk".';


--
-- Name: V_Professionnel_Global; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Global" AS
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
   FROM (((((((professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     JOIN professionnel."T_Professionnel_Entite" pe ON ((pe."IdProfessionnelFk" = p."IdProfessionnel")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = pe."IdEntiteFk")))
     LEFT JOIN systeme."T_Entite_Localisation" el ON ((el."IdEntiteFk" = e."IdEntite")))
     LEFT JOIN referentiel."T_Generique" type_prof ON ((type_prof."ID_Generique" = p."IdTypeProfessionnelFk")))
     LEFT JOIN referentiel."T_Generique" spec ON ((spec."ID_Generique" = p."IdSpecialiteFk")))
     LEFT JOIN referentiel."T_Generique" type_lien ON ((type_lien."ID_Generique" = pe."IdTypeLienFk")));


--
-- Name: VIEW "V_Professionnel_Global"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Global" IS 'Détail administratif au grain professionnel × affiliation × localisation ; plusieurs lignes peuvent correspondre à un professionnel. Ne pas sommer ce registre comme un effectif de professionnels.';


--
-- Name: COLUMN "V_Professionnel_Global"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdProfessionnel" IS 'Identifiant du profil professionnel.';


--
-- Name: COLUMN "V_Professionnel_Global"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Global"."NomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."NomUser" IS 'Nom de l’utilisateur.';


--
-- Name: COLUMN "V_Professionnel_Global"."PrenomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."PrenomUser" IS 'Prénom de l’utilisateur.';


--
-- Name: COLUMN "V_Professionnel_Global"."EmailUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';


--
-- Name: COLUMN "V_Professionnel_Global"."PhoneUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."PhoneUser" IS 'Téléphone utilisateur ; le trigger de normalisation conserve les chiffres sans interpréter le pays.';


--
-- Name: COLUMN "V_Professionnel_Global"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Global"."TypeProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."TypeProfessionnel" IS 'Projection SQL de TypeProfessionnel ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Global"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdSpecialiteFk" IS 'Spécialité du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Global"."Specialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."Specialite" IS 'Projection SQL de Specialite ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Global"."NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."NumeroIdentification" IS 'Numéro d’identification professionnel déclaré ; une chaîne vide est interdite si renseigné.';


--
-- Name: COLUMN "V_Professionnel_Global"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."ExperienceAns" IS 'Nombre d’années d’expérience déclaré pour le professionnel ; valeur négative interdite.';


--
-- Name: COLUMN "V_Professionnel_Global"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."ValideProfessionnel" IS 'Indique si le profil professionnel est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "V_Professionnel_Global"."ObsProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."ObsProfessionnel" IS 'Observations enregistrées sur le profil professionnel.';


--
-- Name: COLUMN "V_Professionnel_Global"."IdEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdEntite" IS 'Identifiant de l’entité.';


--
-- Name: COLUMN "V_Professionnel_Global"."NomEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."NomEntite" IS 'Nom de la structure ou organisation.';


--
-- Name: COLUMN "V_Professionnel_Global"."PhoneEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."PhoneEntite" IS 'Téléphone de contact de l’entité.';


--
-- Name: COLUMN "V_Professionnel_Global"."EmailEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."EmailEntite" IS 'Adresse électronique de contact de l’entité.';


--
-- Name: COLUMN "V_Professionnel_Global"."IdTypeLienFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdTypeLienFk" IS 'Type de relation entre professionnel et entité. Relation imposée : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Global"."TypeLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."TypeLien" IS 'Projection SQL de TypeLien ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Global"."EstPrincipal"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."EstPrincipal" IS 'Indique si ce rattachement professionnel est marqué comme principal.';


--
-- Name: COLUMN "V_Professionnel_Global"."DateDebut"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."DateDebut" IS 'Début du rattachement professionnel à l’entité.';


--
-- Name: COLUMN "V_Professionnel_Global"."DateFin"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."DateFin" IS 'Fin éventuelle du rattachement ; ne peut précéder DateDebut lorsque les deux dates sont renseignées.';


--
-- Name: COLUMN "V_Professionnel_Global"."ObsLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."ObsLien" IS 'Observations enregistrées sur le rattachement professionnel.';


--
-- Name: COLUMN "V_Professionnel_Global"."IdEntiteLocalisation"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdEntiteLocalisation" IS 'Identifiant de la localisation d’entité.';


--
-- Name: COLUMN "V_Professionnel_Global"."Latitude"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."Latitude" IS 'Latitude de la localisation ; coordonnée décimale.';


--
-- Name: COLUMN "V_Professionnel_Global"."Longitude"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."Longitude" IS 'Longitude de la localisation ; coordonnée décimale.';


--
-- Name: COLUMN "V_Professionnel_Global"."IdNiveau_3_Fk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdNiveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Relation imposée : FOREIGN KEY ("IdNiveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3").';


--
-- Name: COLUMN "V_Professionnel_Global"."IdNiveau_4_Fk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdNiveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Relation imposée : FOREIGN KEY ("IdNiveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4").';


--
-- Name: COLUMN "V_Professionnel_Global"."IdNiveau_5_Fk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."IdNiveau_5_Fk" IS 'Unité géographique de rattachement de niveau 5. Relation imposée : FOREIGN KEY ("IdNiveau_5_Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5").';


--
-- Name: COLUMN "V_Professionnel_Global"."AdresseDetaillee"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Global"."AdresseDetaillee" IS 'Adresse détaillée de cette localisation.';


--
-- Name: V_Professionnel_Par_Entite; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Par_Entite" AS
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
   FROM (((((((professionnel."T_Professionnel_Entite" pe
     JOIN professionnel."T_Professionnel" p ON ((p."IdProfessionnel" = pe."IdProfessionnelFk")))
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = pe."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tp ON ((tp."ID_Generique" = p."IdTypeProfessionnelFk")))
     LEFT JOIN referentiel."T_Generique" sp ON ((sp."ID_Generique" = p."IdSpecialiteFk")))
     LEFT JOIN referentiel."T_Generique" te ON ((te."ID_Generique" = e."IdTypeEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tl ON ((tl."ID_Generique" = pe."IdTypeLienFk")));


--
-- Name: VIEW "V_Professionnel_Par_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Par_Entite" IS 'Affiliations administratives au grain professionnel/entité ; les dates restent visibles, y compris pour les liens historiques.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdProfessionnelFk" IS 'Professionnel rattaché à la discussion ou à l’entité. Relation imposée : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."NomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."NomUser" IS 'Nom de l’utilisateur.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."PrenomUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."PrenomUser" IS 'Prénom de l’utilisateur.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."TypeProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."TypeProfessionnel" IS 'Projection SQL de TypeProfessionnel ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdSpecialiteFk" IS 'Spécialité du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."Specialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."Specialite" IS 'Projection SQL de Specialite ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."NomEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."NomEntite" IS 'Nom de la structure ou organisation.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."PhoneEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."PhoneEntite" IS 'Téléphone de contact de l’entité.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."EmailEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."EmailEntite" IS 'Adresse électronique de contact de l’entité.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."AdresseEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."AdresseEntite" IS 'Adresse générale enregistrée pour l’entité.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdTypeEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdTypeEntiteFk" IS 'Type de structure ou d’organisation dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeEntiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."TypeEntite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."TypeEntite" IS 'Projection SQL de TypeEntite ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."EstPrincipal"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."EstPrincipal" IS 'Indique si ce rattachement professionnel est marqué comme principal.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."DateDebut"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."DateDebut" IS 'Début du rattachement professionnel à l’entité.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."DateFin"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."DateFin" IS 'Fin éventuelle du rattachement ; ne peut précéder DateDebut lorsque les deux dates sont renseignées.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."IdTypeLienFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."IdTypeLienFk" IS 'Type de relation entre professionnel et entité. Relation imposée : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."TypeLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."TypeLien" IS 'Projection SQL de TypeLien ; lire le commentaire de la vue pour son grain et son périmètre.';


--
-- Name: COLUMN "V_Professionnel_Par_Entite"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Par_Entite"."ValideProfessionnel" IS 'Indique si le profil professionnel est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: V_Professionnel_Public; Type: VIEW; Schema: professionnel; Owner: -
--

CREATE VIEW professionnel."V_Professionnel_Public" AS
 SELECT p."IdProfessionnel",
    p."ExperienceAns",
    p."ValideProfessionnel",
    jsonb_build_object('ID_Generique', s."ID_Generique", 'NomGenerique', s."NomGenerique", 'AbrGenerique', s."AbrGenerique") AS "T_GeneriqueSpecialite",
    jsonb_build_object('ID_Generique', t."ID_Generique", 'NomGenerique', t."NomGenerique", 'AbrGenerique', t."AbrGenerique") AS "T_GeneriqueType",
    jsonb_build_object('IdUser', u."IdUser", 'NomUser', u."NomUser", 'PrenomUser', u."PrenomUser", 'UrlPhoto', u."UrlPhoto") AS "T_Utilisateurs",
    COALESCE(( SELECT jsonb_agg(jsonb_build_object('EstPrincipal', l."EstPrincipal", 'T_Entite', jsonb_build_object('IdEntite', e."IdEntite", 'NomEntite', e."NomEntite", 'PhoneEntite', e."PhoneEntite", 'AdresseEntite', e."AdresseEntite")) ORDER BY l."EstPrincipal" DESC, l."IdEntiteFk") AS jsonb_agg
           FROM (professionnel."T_Professionnel_Entite" l
             JOIN systeme."T_Entite" e ON ((e."IdEntite" = l."IdEntiteFk")))
          WHERE ((l."IdProfessionnelFk" = p."IdProfessionnel") AND (e."ValideEntite" = true) AND ((l."DateDebut" IS NULL) OR (l."DateDebut" <= CURRENT_TIMESTAMP)) AND ((l."DateFin" IS NULL) OR (l."DateFin" > CURRENT_TIMESTAMP)))), '[]'::jsonb) AS "T_Professionnel_Entite"
   FROM (((professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     LEFT JOIN referentiel."T_Generique" s ON ((s."ID_Generique" = p."IdSpecialiteFk")))
     LEFT JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = p."IdTypeProfessionnelFk")))
  WHERE ((p."ValideProfessionnel" = true) AND (u."ValideUser" = true));


--
-- Name: VIEW "V_Professionnel_Public"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON VIEW professionnel."V_Professionnel_Public" IS 'Annuaire public au grain professionnel actif et utilisateur actif. Identité, spécialité et affiliations valables à la date de lecture ; aucun email, téléphone personnel, numéro professionnel ou mot de passe. Les affiliations sont agrégées pour éviter de dupliquer les professionnels.';


--
-- Name: COLUMN "V_Professionnel_Public"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."IdProfessionnel" IS 'Clé du professionnel public actif, une ligne par professionnel.';


--
-- Name: COLUMN "V_Professionnel_Public"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."ExperienceAns" IS 'Expérience en années déclarée par le professionnel.';


--
-- Name: COLUMN "V_Professionnel_Public"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."ValideProfessionnel" IS 'Vrai pour chaque professionnel de cette projection publique filtrée.';


--
-- Name: COLUMN "V_Professionnel_Public"."T_GeneriqueSpecialite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_GeneriqueSpecialite" IS 'Spécialité publique sous forme JSON : identifiant, nom et abréviation du référentiel.';


--
-- Name: COLUMN "V_Professionnel_Public"."T_GeneriqueType"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_GeneriqueType" IS 'Type professionnel public sous forme JSON : identifiant, nom et abréviation.';


--
-- Name: COLUMN "V_Professionnel_Public"."T_Utilisateurs"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_Utilisateurs" IS 'Identité publique JSON limitée à IdUser, NomUser, PrenomUser et UrlPhoto ; sans email, téléphone personnel ni mot de passe.';


--
-- Name: COLUMN "V_Professionnel_Public"."T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."V_Professionnel_Public"."T_Professionnel_Entite" IS 'Affiliations vers les structures actives, valables à la date de lecture ; tri principal puis identifiant, tableau JSON vide si aucune.';


--
-- Name: T_CategorieGenerique; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_CategorieGenerique" (
    "ID_CategorieGenerique" integer CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" NOT NULL,
    "NomCategorieGenerique" character varying(255),
    "ModuleCategorieGenerique" text,
    "ValideCategorieGenerique" boolean DEFAULT true
);


--
-- Name: TABLE "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_CategorieGenerique" IS 'Catégories de nomenclature : nom, module d’usage et validité. Regroupe les valeurs de T_Generique.';


--
-- Name: COLUMN "T_CategorieGenerique"."ID_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ID_CategorieGenerique" IS 'Identifiant de la catégorie de nomenclature.';


--
-- Name: COLUMN "T_CategorieGenerique"."NomCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature.';


--
-- Name: COLUMN "T_CategorieGenerique"."ModuleCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ModuleCategorieGenerique" IS 'Module ou domaine d’usage de la catégorie de nomenclature.';


--
-- Name: COLUMN "T_CategorieGenerique"."ValideCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ValideCategorieGenerique" IS 'Indique si la catégorie est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" ON "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" ON referentiel."T_CategorieGenerique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_CategorieGenerique". Définition : NOT NULL "ID_CategorieGenerique".';


--
-- Name: T_CategorieGenerique_ID_CategorieGenerique_seq; Type: SEQUENCE; Schema: referentiel; Owner: -
--

ALTER TABLE referentiel."T_CategorieGenerique" ALTER COLUMN "ID_CategorieGenerique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME referentiel."T_CategorieGenerique_ID_CategorieGenerique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_CategorieGenerique_ID_CategorieGenerique_seq"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel."T_CategorieGenerique_ID_CategorieGenerique_seq" IS 'Séquence de génération de "referentiel"."T_CategorieGenerique"."ID_CategorieGenerique". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Generique_ID_Generique_seq; Type: SEQUENCE; Schema: referentiel; Owner: -
--

ALTER TABLE referentiel."T_Generique" ALTER COLUMN "ID_Generique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME referentiel."T_Generique_ID_Generique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Generique_ID_Generique_seq"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel."T_Generique_ID_Generique_seq" IS 'Séquence de génération de "referentiel"."T_Generique"."ID_Generique". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: V_CategorieGenerique; Type: VIEW; Schema: referentiel; Owner: -
--

CREATE VIEW referentiel."V_CategorieGenerique" AS
 SELECT "ID_CategorieGenerique",
    "NomCategorieGenerique",
    "ModuleCategorieGenerique",
    "ValideCategorieGenerique"
   FROM referentiel."T_CategorieGenerique" c
  ORDER BY "NomCategorieGenerique", "ModuleCategorieGenerique";


--
-- Name: VIEW "V_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON VIEW referentiel."V_CategorieGenerique" IS 'Projection au grain catégorie de nomenclature : identité, module d’usage et validité. Aucun filtre de validité n’est appliqué.';


--
-- Name: COLUMN "V_CategorieGenerique"."ID_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."ID_CategorieGenerique" IS 'Identifiant de la catégorie de nomenclature. Expression projetée : "ID_CategorieGenerique".';


--
-- Name: COLUMN "V_CategorieGenerique"."NomCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature. Expression projetée : "NomCategorieGenerique".';


--
-- Name: COLUMN "V_CategorieGenerique"."ModuleCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."ModuleCategorieGenerique" IS 'Module ou domaine d’usage de la catégorie de nomenclature. Expression projetée : "ModuleCategorieGenerique".';


--
-- Name: COLUMN "V_CategorieGenerique"."ValideCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."ValideCategorieGenerique" IS 'Indique si la catégorie est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : "ValideCategorieGenerique".';


--
-- Name: V_Generique; Type: VIEW; Schema: referentiel; Owner: -
--

CREATE VIEW referentiel."V_Generique" AS
 SELECT g."ID_CategorieGeneriqueFk",
    c."NomCategorieGenerique",
    c."ModuleCategorieGenerique",
    g."ID_Generique",
    g."NomGenerique",
    g."AbrGenerique",
    g."VisibleNiveau_2",
    g."VisibleNiveau_3",
    g."VisibleNiveau_4",
    g."VisibleNiveau_5",
    g."VisibleArticle",
    g."VisibleCmd",
    g."VisibleFacture",
    g."VisibleUsers",
    g."VisibleVoie",
    g."VisibleAll",
    g."ObsGenerique",
    g."ValideGenerique"
   FROM (referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c ON ((g."ID_CategorieGeneriqueFk" = c."ID_CategorieGenerique")))
  ORDER BY c."NomCategorieGenerique", g."NomGenerique", g."AbrGenerique";


--
-- Name: VIEW "V_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON VIEW referentiel."V_Generique" IS 'Valeurs de nomenclature enrichies avec leur catégorie et module, au grain valeur générique ; expose visibilité et validité sans filtrer les valeurs inactives.';


--
-- Name: COLUMN "V_Generique"."ID_CategorieGeneriqueFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ID_CategorieGeneriqueFk" IS 'Catégorie à laquelle appartient cette valeur de nomenclature. Expression projetée : g."ID_CategorieGeneriqueFk".';


--
-- Name: COLUMN "V_Generique"."NomCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature. Expression projetée : c."NomCategorieGenerique".';


--
-- Name: COLUMN "V_Generique"."ModuleCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ModuleCategorieGenerique" IS 'Module ou domaine d’usage de la catégorie de nomenclature. Expression projetée : c."ModuleCategorieGenerique".';


--
-- Name: COLUMN "V_Generique"."ID_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ID_Generique" IS 'Identifiant d’une valeur de nomenclature. Expression projetée : g."ID_Generique".';


--
-- Name: COLUMN "V_Generique"."NomGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."NomGenerique" IS 'Libellé métier de la valeur de nomenclature. Expression projetée : g."NomGenerique".';


--
-- Name: COLUMN "V_Generique"."AbrGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."AbrGenerique" IS 'Abréviation de la valeur de nomenclature ; peut porter un code de type utilisé par les règles métier. Expression projetée : g."AbrGenerique".';


--
-- Name: COLUMN "V_Generique"."VisibleNiveau_2"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleNiveau_2" IS 'Indicateur de visibilité pour le niveau géographique de niveau 2. Expression projetée : g."VisibleNiveau_2".';


--
-- Name: COLUMN "V_Generique"."VisibleNiveau_3"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleNiveau_3" IS 'Indicateur de visibilité pour le niveau géographique de niveau 3. Expression projetée : g."VisibleNiveau_3".';


--
-- Name: COLUMN "V_Generique"."VisibleNiveau_4"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleNiveau_4" IS 'Indicateur de visibilité pour le niveau géographique de niveau 4. Expression projetée : g."VisibleNiveau_4".';


--
-- Name: COLUMN "V_Generique"."VisibleNiveau_5"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5. Expression projetée : g."VisibleNiveau_5".';


--
-- Name: COLUMN "V_Generique"."VisibleArticle"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleArticle" IS 'Indique la visibilité de la valeur de nomenclature pour les articles. Expression projetée : g."VisibleArticle".';


--
-- Name: COLUMN "V_Generique"."VisibleCmd"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleCmd" IS 'Indique la visibilité de la valeur de nomenclature pour les commandes. Expression projetée : g."VisibleCmd".';


--
-- Name: COLUMN "V_Generique"."VisibleFacture"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleFacture" IS 'Indique la visibilité de la valeur de nomenclature pour les factures. Expression projetée : g."VisibleFacture".';


--
-- Name: COLUMN "V_Generique"."VisibleUsers"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleUsers" IS 'Indique la visibilité de la valeur de nomenclature pour les utilisateurs. Expression projetée : g."VisibleUsers".';


--
-- Name: COLUMN "V_Generique"."VisibleVoie"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleVoie" IS 'Indique la visibilité de la valeur de nomenclature pour les voies d’accès. Expression projetée : g."VisibleVoie".';


--
-- Name: COLUMN "V_Generique"."VisibleAll"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleAll" IS 'Indique la visibilité générale de la valeur de nomenclature. Expression projetée : g."VisibleAll".';


--
-- Name: COLUMN "V_Generique"."ObsGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ObsGenerique" IS 'Observations enregistrées sur la valeur de nomenclature. Expression projetée : g."ObsGenerique".';


--
-- Name: COLUMN "V_Generique"."ValideGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ValideGenerique" IS 'Indique si la valeur de nomenclature est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : g."ValideGenerique".';


--
-- Name: T_Admin_UI_Setting; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Admin_UI_Setting" (
    "IdAdminUISetting" integer CONSTRAINT "T_Admin_UI_Setting_IdAdminUISetting_not_null" NOT NULL,
    "SettingScope" character varying(50) DEFAULT 'global'::character varying CONSTRAINT "T_Admin_UI_Setting_SettingScope_not_null" NOT NULL,
    "ScopeValue" character varying(100),
    "SettingKey" character varying(100) CONSTRAINT "T_Admin_UI_Setting_SettingKey_not_null" NOT NULL,
    "SettingLabel" character varying(150),
    "SettingGroup" character varying(100) DEFAULT 'general'::character varying,
    "SettingValue" text,
    "SettingValueJson" jsonb,
    "SettingType" character varying(50) DEFAULT 'text'::character varying,
    "DisplayOrder" integer DEFAULT 0,
    "IsEditable" boolean DEFAULT true,
    "IsSystem" boolean DEFAULT false,
    "ValideSetting" boolean DEFAULT true,
    "CreatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "UpdatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "UpdatedByUserFk" integer,
    "ObsSetting" text,
    CONSTRAINT "Ck_Admin_UI_Setting_Scope" CHECK ((("SettingScope")::text = ANY (ARRAY[('global'::character varying)::text, ('entite'::character varying)::text, ('user'::character varying)::text, ('module'::character varying)::text]))),
    CONSTRAINT "Ck_Admin_UI_Setting_Type" CHECK ((("SettingType")::text = ANY (ARRAY[('text'::character varying)::text, ('number'::character varying)::text, ('boolean'::character varying)::text, ('select'::character varying)::text, ('json'::character varying)::text, ('color'::character varying)::text, ('file'::character varying)::text, ('email'::character varying)::text, ('phone'::character varying)::text, ('url'::character varying)::text, ('textarea'::character varying)::text])))
);


--
-- Name: TABLE "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Admin_UI_Setting" IS 'Paramètres d’interface partagés avec portée, clé, groupe, type et valeur texte/JSON. La contrainte installée admet les portées global, entite, user et module ; UpdatedAt est actualisé par trigger.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."IdAdminUISetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."IdAdminUISetting" IS 'Identifiant du paramètre d’interface.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingScope" IS 'Portée du paramètre d’interface ; la contrainte actuellement installée admet global, entite, user et module. Distincte de la portée des correspondances FK.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingKey" IS 'Clé technique stable du paramètre.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingLabel" IS 'Libellé du paramètre présenté dans l’administration.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingGroup"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingGroup" IS 'Groupe fonctionnel du paramètre d’interface.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingValue" IS 'Valeur du paramètre sous forme textuelle.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingValueJson"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingValueJson" IS 'Valeur structurée JSON du paramètre ; distincte de la représentation textuelle.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingType" IS 'Type de représentation du paramètre contrôlé par la contrainte installée.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."DisplayOrder"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."DisplayOrder" IS 'Ordre d’affichage du paramètre ou de la correspondance.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."IsEditable"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."IsEditable" IS 'Indique si le paramètre est déclaré modifiable dans l’interface.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."IsSystem"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."IsSystem" IS 'Identifie un paramètre système.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."ValideSetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."ValideSetting" IS 'Indique si le paramètre est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."CreatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."CreatedAt" IS 'Horodatage de création du paramètre.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."UpdatedByUserFk" IS 'Utilisateur ayant enregistré la dernière modification du paramètre ou de la correspondance. Relation imposée : FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."ObsSetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."ObsSetting" IS 'Observations enregistrées sur le paramètre.';


--
-- Name: CONSTRAINT "T_Admin_UI_Setting_IdAdminUISetting_not_null" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Admin_UI_Setting_IdAdminUISetting_not_null" ON systeme."T_Admin_UI_Setting" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Admin_UI_Setting". Définition : NOT NULL "IdAdminUISetting".';


--
-- Name: CONSTRAINT "T_Admin_UI_Setting_SettingScope_not_null" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Admin_UI_Setting_SettingScope_not_null" ON systeme."T_Admin_UI_Setting" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Admin_UI_Setting". Définition : NOT NULL "SettingScope".';


--
-- Name: CONSTRAINT "T_Admin_UI_Setting_SettingKey_not_null" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Admin_UI_Setting_SettingKey_not_null" ON systeme."T_Admin_UI_Setting" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Admin_UI_Setting". Définition : NOT NULL "SettingKey".';


--
-- Name: CONSTRAINT "Ck_Admin_UI_Setting_Scope" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Admin_UI_Setting_Scope" ON systeme."T_Admin_UI_Setting" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Admin_UI_Setting". Définition : CHECK ("SettingScope"::text = ANY (ARRAY[''global''::character varying::text, ''entite''::character varying::text, ''user''::character varying::text, ''module''::character varying::text])).';


--
-- Name: CONSTRAINT "Ck_Admin_UI_Setting_Type" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Admin_UI_Setting_Type" ON systeme."T_Admin_UI_Setting" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Admin_UI_Setting". Définition : CHECK ("SettingType"::text = ANY (ARRAY[''text''::character varying::text, ''number''::character varying::text, ''boolean''::character varying::text, ''select''::character varying::text, ''json''::character varying::text, ''color''::character varying::text, ''file''::character varying::text, ''email''::character varying::text, ''phone''::character varying::text, ''url''::character varying::text, ''textarea''::character varying::text])).';


--
-- Name: T_Admin_UI_Setting_IdAdminUISetting_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Admin_UI_Setting" ALTER COLUMN "IdAdminUISetting" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME systeme."T_Admin_UI_Setting_IdAdminUISetting_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Admin_UI_Setting_IdAdminUISetting_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Admin_UI_Setting_IdAdminUISetting_seq" IS 'Séquence de génération de "systeme"."T_Admin_UI_Setting"."IdAdminUISetting". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Audit_Log; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Audit_Log" (
    "IdLog" integer CONSTRAINT "T_Audit_Log_IdLog_not_null" NOT NULL,
    "TableName" text,
    "Operation" text,
    "OldData" jsonb,
    "NewData" jsonb,
    "ChangedAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "IdEntiteFk" integer
);


--
-- Name: TABLE "T_Audit_Log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Audit_Log" IS 'Événements d’audit : table, opération, instant, valeurs avant/après en JSON et entité éventuelle. Les événements proviennent des triggers raccordés ou des écritures explicites de l’application.';


--
-- Name: COLUMN "T_Audit_Log"."IdLog"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."IdLog" IS 'Identifiant de l’événement d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."TableName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."TableName" IS 'Nom de la table à l’origine de l’événement d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."Operation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."Operation" IS 'Nom de l’opération auditée ; le trigger produit INSERT, UPDATE ou DELETE.';


--
-- Name: COLUMN "T_Audit_Log"."OldData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."OldData" IS 'Valeurs avant l’opération auditable, sérialisées en JSON ; NULL lors d’une insertion par le trigger d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."NewData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."NewData" IS 'Valeurs après l’opération auditable, sérialisées en JSON ; NULL lors d’une suppression par le trigger d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."ChangedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."ChangedAt" IS 'Horodatage de l’événement d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: CONSTRAINT "T_Audit_Log_IdLog_not_null" ON "T_Audit_Log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Audit_Log_IdLog_not_null" ON systeme."T_Audit_Log" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Audit_Log". Définition : NOT NULL "IdLog".';


--
-- Name: T_Audit_Log_IdLog_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Audit_Log" ALTER COLUMN "IdLog" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Audit_Log_IdLog_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Audit_Log_IdLog_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Audit_Log_IdLog_seq" IS 'Séquence de génération de "systeme"."T_Audit_Log"."IdLog". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Entite_IdEntite_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Entite" ALTER COLUMN "IdEntite" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Entite_IdEntite_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Entite_IdEntite_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Entite_IdEntite_seq" IS 'Séquence de génération de "systeme"."T_Entite"."IdEntite". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Entite_Localisation_IdEntiteLocalisation_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Entite_Localisation" ALTER COLUMN "IdEntiteLocalisation" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Entite_Localisation_IdEntiteLocalisation_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Entite_Localisation_IdEntiteLocalisation_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Entite_Localisation_IdEntiteLocalisation_seq" IS 'Séquence de génération de "systeme"."T_Entite_Localisation"."IdEntiteLocalisation". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Fk_Correspondance; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Fk_Correspondance" (
    "IdFkCorrespondance" integer CONSTRAINT "T_Fk_Correspondance_IdFkCorrespondance_not_null" NOT NULL,
    "ModuleName" character varying(80) CONSTRAINT "T_Fk_Correspondance_ModuleName_not_null" NOT NULL,
    "SchemaName" character varying(80) CONSTRAINT "T_Fk_Correspondance_SchemaName_not_null" NOT NULL,
    "ViewName" character varying(120),
    "SourceKey" character varying(120) CONSTRAINT "T_Fk_Correspondance_SourceKey_not_null" NOT NULL,
    "FieldName" character varying(120) CONSTRAINT "T_Fk_Correspondance_FieldName_not_null" NOT NULL,
    "FieldLabel" character varying(255),
    "MappingType" character varying(40) DEFAULT 'generic_category'::character varying CONSTRAINT "T_Fk_Correspondance_MappingType_not_null" NOT NULL,
    "ReferenceSchemaName" character varying(80),
    "ReferenceObjectName" character varying(120),
    "ReferenceFieldName" character varying(120),
    "TargetCategoryIdFk" integer,
    "MappingValue" character varying(120) CONSTRAINT "T_Fk_Correspondance_MappingValue_not_null" NOT NULL,
    "IsDefaultMapping" boolean DEFAULT false CONSTRAINT "T_Fk_Correspondance_IsDefaultMapping_not_null" NOT NULL,
    "ValideFkCorrespondance" boolean DEFAULT true CONSTRAINT "T_Fk_Correspondance_ValideFkCorrespondance_not_null" NOT NULL,
    "SettingScope" character varying(60) DEFAULT 'global'::character varying CONSTRAINT "T_Fk_Correspondance_SettingScope_not_null" NOT NULL,
    "ScopeValue" character varying(120),
    "DisplayOrder" integer DEFAULT 0 CONSTRAINT "T_Fk_Correspondance_DisplayOrder_not_null" NOT NULL,
    "UpdatedAt" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Fk_Correspondance_UpdatedAt_not_null" NOT NULL,
    "UpdatedByUserFk" integer,
    "ObsFkCorrespondance" text,
    CONSTRAINT chk_fkcorrespondance_mappingtype CHECK ((("MappingType")::text = ANY (ARRAY[('generic_category'::character varying)::text, ('direct_source'::character varying)::text, ('hierarchy_mode'::character varying)::text]))),
    CONSTRAINT chk_fkcorrespondance_scope CHECK ((("SettingScope")::text = ANY (ARRAY[('global'::character varying)::text, ('country'::character varying)::text, ('entity'::character varying)::text])))
);


--
-- Name: TABLE "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Fk_Correspondance" IS 'Correspondances configurables des champs et sources de listes : catégorie ou source directe, portée global/country/entity, ordre, validité et auteur de modification.';


--
-- Name: COLUMN "T_Fk_Correspondance"."IdFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."IdFkCorrespondance" IS 'Identifiant de la correspondance de champ.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ModuleName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ModuleName" IS 'Module applicatif auquel s’applique la correspondance.';


--
-- Name: COLUMN "T_Fk_Correspondance"."SchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."SchemaName" IS 'Schéma PostgreSQL de la vue dont le champ est configuré.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ViewName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ViewName" IS 'Nom de la vue dont les correspondances de champ sont configurées.';


--
-- Name: COLUMN "T_Fk_Correspondance"."SourceKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."SourceKey" IS 'Clé applicative de la source de liste configurée.';


--
-- Name: COLUMN "T_Fk_Correspondance"."FieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."FieldName" IS 'Nom technique du champ dont la source de liste est configurée.';


--
-- Name: COLUMN "T_Fk_Correspondance"."FieldLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."FieldLabel" IS 'Libellé du champ présenté dans le paramétrage des correspondances.';


--
-- Name: COLUMN "T_Fk_Correspondance"."MappingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."MappingType" IS 'Mode de correspondance : generic_category, direct_source ou hierarchy_mode, selon la contrainte installée.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ReferenceSchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ReferenceSchemaName" IS 'Schéma PostgreSQL de l’objet de référence configuré.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ReferenceObjectName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ReferenceObjectName" IS 'Nom technique de l’objet de référence configuré pour la liste.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ReferenceFieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ReferenceFieldName" IS 'Champ identifiant ou libellé utilisé dans l’objet de référence configuré.';


--
-- Name: COLUMN "T_Fk_Correspondance"."TargetCategoryIdFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."TargetCategoryIdFk" IS 'Catégorie de nomenclature ciblée par une correspondance de type generic_category. Relation imposée : FOREIGN KEY ("TargetCategoryIdFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Fk_Correspondance"."MappingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."MappingValue" IS 'Valeur de configuration associée à la correspondance.';


--
-- Name: COLUMN "T_Fk_Correspondance"."IsDefaultMapping"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."IsDefaultMapping" IS 'Indique une correspondance proposée par défaut.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ValideFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ValideFkCorrespondance" IS 'Indique si la correspondance est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Fk_Correspondance"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."SettingScope" IS 'Portée de la correspondance FK : global, country ou entity selon la contrainte installée.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès.';


--
-- Name: COLUMN "T_Fk_Correspondance"."DisplayOrder"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."DisplayOrder" IS 'Ordre d’affichage du paramètre ou de la correspondance.';


--
-- Name: COLUMN "T_Fk_Correspondance"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré.';


--
-- Name: COLUMN "T_Fk_Correspondance"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."UpdatedByUserFk" IS 'Utilisateur ayant enregistré la dernière modification du paramètre ou de la correspondance. Relation imposée : FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ObsFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ObsFkCorrespondance" IS 'Observations enregistrées sur la correspondance.';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_IdFkCorrespondance_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_IdFkCorrespondance_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "IdFkCorrespondance".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_ModuleName_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_ModuleName_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "ModuleName".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_SchemaName_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_SchemaName_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "SchemaName".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_SourceKey_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_SourceKey_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "SourceKey".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_FieldName_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_FieldName_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "FieldName".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_MappingType_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_MappingType_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "MappingType".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_MappingValue_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_MappingValue_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "MappingValue".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_IsDefaultMapping_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_IsDefaultMapping_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "IsDefaultMapping".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_ValideFkCorrespondance_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_ValideFkCorrespondance_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "ValideFkCorrespondance".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_SettingScope_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_SettingScope_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "SettingScope".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_DisplayOrder_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_DisplayOrder_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "DisplayOrder".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_UpdatedAt_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_UpdatedAt_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "UpdatedAt".';


--
-- Name: CONSTRAINT chk_fkcorrespondance_mappingtype ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT chk_fkcorrespondance_mappingtype ON systeme."T_Fk_Correspondance" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Fk_Correspondance". Définition : CHECK ("MappingType"::text = ANY (ARRAY[''generic_category''::character varying::text, ''direct_source''::character varying::text, ''hierarchy_mode''::character varying::text])).';


--
-- Name: CONSTRAINT chk_fkcorrespondance_scope ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT chk_fkcorrespondance_scope ON systeme."T_Fk_Correspondance" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Fk_Correspondance". Définition : CHECK ("SettingScope"::text = ANY (ARRAY[''global''::character varying::text, ''country''::character varying::text, ''entity''::character varying::text])).';


--
-- Name: T_Fk_Correspondance_IdFkCorrespondance_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Fk_Correspondance" ALTER COLUMN "IdFkCorrespondance" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Fk_Correspondance_IdFkCorrespondance_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Fk_Correspondance_IdFkCorrespondance_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Fk_Correspondance_IdFkCorrespondance_seq" IS 'Séquence de génération de "systeme"."T_Fk_Correspondance"."IdFkCorrespondance". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Licence; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Licence" (
    "IdLicence" integer CONSTRAINT "T_Licence_IdLicence_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Licence_IdEntiteFk_not_null" NOT NULL,
    "CleLicence" uuid DEFAULT gen_random_uuid(),
    "DateDebut" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "DateFin" timestamp without time zone CONSTRAINT "T_Licence_DateFin_not_null" NOT NULL,
    "IdStatutLicenceFk" integer CONSTRAINT "T_Licence_IdStatutLicenceFk_not_null" NOT NULL,
    "ValideLicence" boolean DEFAULT true,
    "ExpireeLicence" boolean DEFAULT false,
    CONSTRAINT chk_licence_dates CHECK (("DateFin" > "DateDebut"))
);


--
-- Name: TABLE "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Licence" IS 'Licences des entités avec clé UUID, période, statut et indicateurs de validité/expiration. Les triggers contrôlent les insertions et actualisent l’expiration lors des écritures ; aucune tâche périodique n’est définie par ces triggers.';


--
-- Name: COLUMN "T_Licence"."IdLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."IdLicence" IS 'Identifiant automatiquement attribué par une identité PostgreSQL ; les identifiants antérieurs sont conservés.';


--
-- Name: COLUMN "T_Licence"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Licence"."CleLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."CleLicence" IS 'Clé UUID identifiant la licence.';


--
-- Name: COLUMN "T_Licence"."DateDebut"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."DateDebut" IS 'Début de validité de la licence.';


--
-- Name: COLUMN "T_Licence"."DateFin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."DateFin" IS 'Fin de validité de la licence, strictement postérieure à DateDebut selon la contrainte.';


--
-- Name: COLUMN "T_Licence"."IdStatutLicenceFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."IdStatutLicenceFk" IS 'Statut de licence dans le référentiel. Relation imposée : FOREIGN KEY ("IdStatutLicenceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Licence"."ValideLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."ValideLicence" IS 'Indique si la licence est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Licence"."ExpireeLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."ExpireeLicence" IS 'Indicateur d’expiration calculé à l’écriture de la licence à partir de DateFin ; ne se met pas à jour seul avec le passage du temps.';


--
-- Name: CONSTRAINT "T_Licence_IdLicence_not_null" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Licence_IdLicence_not_null" ON systeme."T_Licence" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Licence". Définition : NOT NULL "IdLicence".';


--
-- Name: CONSTRAINT "T_Licence_IdEntiteFk_not_null" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Licence_IdEntiteFk_not_null" ON systeme."T_Licence" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Licence". Définition : NOT NULL "IdEntiteFk".';


--
-- Name: CONSTRAINT "T_Licence_DateFin_not_null" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Licence_DateFin_not_null" ON systeme."T_Licence" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Licence". Définition : NOT NULL "DateFin".';


--
-- Name: CONSTRAINT "T_Licence_IdStatutLicenceFk_not_null" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Licence_IdStatutLicenceFk_not_null" ON systeme."T_Licence" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Licence". Définition : NOT NULL "IdStatutLicenceFk".';


--
-- Name: CONSTRAINT chk_licence_dates ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT chk_licence_dates ON systeme."T_Licence" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Licence". Définition : CHECK ("DateFin" > "DateDebut").';


--
-- Name: T_Licence_IdLicence_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Licence" ALTER COLUMN "IdLicence" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME systeme."T_Licence_IdLicence_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Licence_IdLicence_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Licence_IdLicence_seq" IS 'Séquence technique d’identité attribuant les identifiants sans réécrire les lignes existantes.';


--
-- Name: T_Login; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Login" (
    "IdLogin" integer CONSTRAINT "T_Login_IdLogin_not_null" NOT NULL,
    "IdUserFk" integer CONSTRAINT "T_Login_IdUserFk_not_null" NOT NULL,
    "IdTypeLoginFk" integer CONSTRAINT "T_Login_IdTypeLoginFk_not_null" NOT NULL,
    "DateLogin" timestamp with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Login_DateLogin_not_null" NOT NULL,
    "IdEntiteFk" integer
);


--
-- Name: TABLE "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Login" IS 'Événements de connexion liés à un utilisateur, un type de connexion et une entité éventuelle.';


--
-- Name: COLUMN "T_Login"."IdLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."IdLogin" IS 'Identifiant de l’événement de connexion.';


--
-- Name: COLUMN "T_Login"."IdUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Login"."IdTypeLoginFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."IdTypeLoginFk" IS 'Type de l’événement de connexion dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeLoginFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Login"."DateLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."DateLogin" IS 'Date et heure de l’événement de connexion.';


--
-- Name: COLUMN "T_Login"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: CONSTRAINT "T_Login_IdLogin_not_null" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Login_IdLogin_not_null" ON systeme."T_Login" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Login". Définition : NOT NULL "IdLogin".';


--
-- Name: CONSTRAINT "T_Login_IdUserFk_not_null" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Login_IdUserFk_not_null" ON systeme."T_Login" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Login". Définition : NOT NULL "IdUserFk".';


--
-- Name: CONSTRAINT "T_Login_IdTypeLoginFk_not_null" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Login_IdTypeLoginFk_not_null" ON systeme."T_Login" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Login". Définition : NOT NULL "IdTypeLoginFk".';


--
-- Name: CONSTRAINT "T_Login_DateLogin_not_null" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Login_DateLogin_not_null" ON systeme."T_Login" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Login". Définition : NOT NULL "DateLogin".';


--
-- Name: T_Login_IdLogin_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Login" ALTER COLUMN "IdLogin" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Login_IdLogin_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Login_IdLogin_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Login_IdLogin_seq" IS 'Séquence de génération de "systeme"."T_Login"."IdLogin". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Utilisateurs_IdUser_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Utilisateurs" ALTER COLUMN "IdUser" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Utilisateurs_IdUser_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Utilisateurs_IdUser_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Utilisateurs_IdUser_seq" IS 'Séquence de génération de "systeme"."T_Utilisateurs"."IdUser". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: V_Admin_UI_Setting; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Admin_UI_Setting" AS
 SELECT s."IdAdminUISetting",
    s."SettingScope",
    s."ScopeValue",
    s."SettingKey",
    s."SettingLabel",
    s."SettingGroup",
    s."SettingValue",
    s."SettingValueJson",
    s."SettingType",
    s."DisplayOrder",
    s."IsEditable",
    s."IsSystem",
    s."ValideSetting",
    s."CreatedAt",
    s."UpdatedAt",
    s."UpdatedByUserFk",
    COALESCE(NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text),
        CASE
            WHEN (s."UpdatedByUserFk" IS NOT NULL) THEN ('Utilisateur #'::text || s."UpdatedByUserFk")
            ELSE NULL::text
        END) AS "UpdatedByName",
    s."ObsSetting"
   FROM (systeme."T_Admin_UI_Setting" s
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = s."UpdatedByUserFk")))
  WHERE (s."ValideSetting" = true)
  ORDER BY s."SettingGroup", s."DisplayOrder", s."SettingLabel";


--
-- Name: VIEW "V_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Admin_UI_Setting" IS 'Paramètres déclarés valides, enrichis du nom du dernier modificateur ; grain paramètre. La portée est exposée sans imposer d’autorisation utilisateur.';


--
-- Name: COLUMN "V_Admin_UI_Setting"."IdAdminUISetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."IdAdminUISetting" IS 'Identifiant du paramètre d’interface. Expression projetée : s."IdAdminUISetting".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingScope" IS 'Niveau de portée du paramètre ou de la correspondance ; consulter la contrainte de la table pour les valeurs admises. Expression projetée : s."SettingScope".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès. Expression projetée : s."ScopeValue".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingKey" IS 'Clé technique stable du paramètre. Expression projetée : s."SettingKey".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingLabel" IS 'Libellé du paramètre présenté dans l’administration. Expression projetée : s."SettingLabel".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingGroup"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingGroup" IS 'Groupe fonctionnel du paramètre d’interface. Expression projetée : s."SettingGroup".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingValue" IS 'Valeur du paramètre sous forme textuelle. Expression projetée : s."SettingValue".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingValueJson"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingValueJson" IS 'Valeur structurée JSON du paramètre ; distincte de la représentation textuelle. Expression projetée : s."SettingValueJson".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingType" IS 'Type de représentation du paramètre contrôlé par la contrainte installée. Expression projetée : s."SettingType".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."DisplayOrder"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."DisplayOrder" IS 'Ordre d’affichage du paramètre ou de la correspondance. Expression projetée : s."DisplayOrder".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."IsEditable"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."IsEditable" IS 'Indique si le paramètre est déclaré modifiable dans l’interface. Expression projetée : s."IsEditable".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."IsSystem"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."IsSystem" IS 'Identifie un paramètre système. Expression projetée : s."IsSystem".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."ValideSetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."ValideSetting" IS 'Indique si le paramètre est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : s."ValideSetting".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."CreatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."CreatedAt" IS 'Horodatage de création du paramètre. Expression projetée : s."CreatedAt".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré. Expression projetée : s."UpdatedAt".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."UpdatedByUserFk" IS 'Utilisateur ayant enregistré la dernière modification du paramètre ou de la correspondance. Expression projetée : s."UpdatedByUserFk".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."UpdatedByName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."UpdatedByName" IS 'Nom du dernier modificateur ; repli Utilisateur #identifiant lorsque le compte n’est pas résolu. Expression projetée : COALESCE(NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''''::character varying), '' '', COALESCE(u."NomUser", ''''::character varying))), ''''::text), CASE WHEN s."UpdatedByUserFk" IS NOT NULL THEN ''Utilisateur #''::text || s."UpdatedByUserFk" ELSE NULL::text END) AS "UpdatedByName".';


--
-- Name: COLUMN "V_Admin_UI_Setting"."ObsSetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."ObsSetting" IS 'Observations enregistrées sur le paramètre. Expression projetée : s."ObsSetting".';


--
-- Name: V_Admin_UI_Setting_Audit; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Admin_UI_Setting_Audit" AS
 SELECT "IdLog",
    "TableName",
    "Operation",
    "ChangedAt",
    COALESCE(("NewData" ->> 'settingScope'::text), ("OldData" ->> 'settingScope'::text), 'global'::text) AS "SettingScope",
    COALESCE(("NewData" ->> 'scopeValue'::text), ("OldData" ->> 'scopeValue'::text)) AS "ScopeValue",
    COALESCE(("NewData" ->> 'settingKey'::text), ("OldData" ->> 'settingKey'::text)) AS "SettingKey",
    COALESCE(("NewData" ->> 'settingLabel'::text), ("OldData" ->> 'settingLabel'::text)) AS "SettingLabel",
    COALESCE(("NewData" ->> 'settingGroup'::text), ("OldData" ->> 'settingGroup'::text)) AS "SettingGroup",
    COALESCE(("NewData" ->> 'settingValue'::text), ("OldData" ->> 'settingValue'::text)) AS "SettingValue",
    COALESCE(("NewData" ->> 'updatedByName'::text), ("OldData" ->> 'updatedByName'::text)) AS "UpdatedByName",
    COALESCE(("NewData" ->> 'updatedByUserId'::text), ("OldData" ->> 'updatedByUserId'::text)) AS "UpdatedByUserId",
    COALESCE(("NewData" ->> 'updatedAt'::text), ("OldData" ->> 'updatedAt'::text)) AS "UpdatedSettingAt",
    "OldData",
    "NewData"
   FROM systeme."T_Audit_Log" a
  WHERE ("TableName" = 'T_Admin_UI_Setting'::text)
  ORDER BY "ChangedAt" DESC;


--
-- Name: VIEW "V_Admin_UI_Setting_Audit"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Admin_UI_Setting_Audit" IS 'Événements de T_Audit_Log filtrés sur T_Admin_UI_Setting, avec extraction des clés JSON applicatives en camelCase depuis NewData puis OldData. Grain événement ; des clés absentes restent NULL, portée globale en repli.';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."IdLog"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."IdLog" IS 'Identifiant de l’événement d’audit. Expression projetée : "IdLog".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."TableName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."TableName" IS 'Nom de la table à l’origine de l’événement d’audit. Expression projetée : "TableName".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."Operation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."Operation" IS 'Nom de l’opération auditée ; le trigger produit INSERT, UPDATE ou DELETE. Expression projetée : "Operation".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."ChangedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."ChangedAt" IS 'Horodatage de l’événement d’audit. Expression projetée : "ChangedAt".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingScope" IS 'Niveau de portée du paramètre ou de la correspondance ; consulter la contrainte de la table pour les valeurs admises. Expression projetée : COALESCE("NewData" ->> ''settingScope''::text, "OldData" ->> ''settingScope''::text, ''global''::text) AS "SettingScope".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès. Expression projetée : COALESCE("NewData" ->> ''scopeValue''::text, "OldData" ->> ''scopeValue''::text) AS "ScopeValue".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingKey" IS 'Clé technique stable du paramètre. Expression projetée : COALESCE("NewData" ->> ''settingKey''::text, "OldData" ->> ''settingKey''::text) AS "SettingKey".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingLabel" IS 'Libellé du paramètre présenté dans l’administration. Expression projetée : COALESCE("NewData" ->> ''settingLabel''::text, "OldData" ->> ''settingLabel''::text) AS "SettingLabel".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingGroup"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingGroup" IS 'Groupe fonctionnel du paramètre d’interface. Expression projetée : COALESCE("NewData" ->> ''settingGroup''::text, "OldData" ->> ''settingGroup''::text) AS "SettingGroup".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingValue" IS 'Valeur du paramètre sous forme textuelle. Expression projetée : COALESCE("NewData" ->> ''settingValue''::text, "OldData" ->> ''settingValue''::text) AS "SettingValue".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."UpdatedByName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedByName" IS 'Nom du dernier modificateur ; repli Utilisateur #identifiant lorsque le compte n’est pas résolu. Expression projetée : COALESCE("NewData" ->> ''updatedByName''::text, "OldData" ->> ''updatedByName''::text) AS "UpdatedByName".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."UpdatedByUserId"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedByUserId" IS 'Identifiant du modificateur extrait du JSON d’audit applicatif ; représentation textuelle. Expression projetée : COALESCE("NewData" ->> ''updatedByUserId''::text, "OldData" ->> ''updatedByUserId''::text) AS "UpdatedByUserId".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."UpdatedSettingAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedSettingAt" IS 'Horodatage de modification extrait des clés JSON d’audit ; représentation textuelle. Expression projetée : COALESCE("NewData" ->> ''updatedAt''::text, "OldData" ->> ''updatedAt''::text) AS "UpdatedSettingAt".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."OldData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."OldData" IS 'Valeurs avant l’opération auditable, sérialisées en JSON ; NULL lors d’une insertion par le trigger d’audit. Expression projetée : "OldData".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."NewData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."NewData" IS 'Valeurs après l’opération auditable, sérialisées en JSON ; NULL lors d’une suppression par le trigger d’audit. Expression projetée : "NewData".';


--
-- Name: V_Admin_UI_Setting_Group; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Admin_UI_Setting_Group" AS
 SELECT "SettingGroup",
    count(*) AS "NbParametres",
    count(*) FILTER (WHERE ("IsEditable" = true)) AS "NbEditables",
    count(*) FILTER (WHERE ("IsSystem" = true)) AS "NbSysteme",
    max("UpdatedAt") AS "DerniereModification"
   FROM systeme."T_Admin_UI_Setting"
  WHERE ("ValideSetting" = true)
  GROUP BY "SettingGroup"
  ORDER BY "SettingGroup";


--
-- Name: VIEW "V_Admin_UI_Setting_Group"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Admin_UI_Setting_Group" IS 'Agrégats des paramètres valides au grain SettingGroup : nombre total, éditables, système et dernière modification. Les portées ne sont pas séparées dans le regroupement.';


--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."SettingGroup"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."SettingGroup" IS 'Groupe fonctionnel du paramètre d’interface. Expression projetée : "SettingGroup".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."NbParametres"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."NbParametres" IS 'Nombre de paramètres valides du groupe, toutes portées confondues. Expression projetée : count(*) AS "NbParametres".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."NbEditables"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."NbEditables" IS 'Nombre de paramètres valides du groupe dont IsEditable vaut true. Expression projetée : count(*) FILTER (WHERE "IsEditable" = true) AS "NbEditables".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."NbSysteme"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."NbSysteme" IS 'Nombre de paramètres valides du groupe dont IsSystem vaut true. Expression projetée : count(*) FILTER (WHERE "IsSystem" = true) AS "NbSysteme".';


--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."DerniereModification"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."DerniereModification" IS 'Dernier UpdatedAt des paramètres valides du groupe. Expression projetée : max("UpdatedAt") AS "DerniereModification".';


--
-- Name: V_Audit_log; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Audit_log" AS
 SELECT a."IdLog",
    a."TableName",
    a."Operation",
    a."ChangedAt",
    e."NomEntite",
    systeme.fn_audit_sans_secrets(a."OldData") AS "OldData",
    systeme.fn_audit_sans_secrets(a."NewData") AS "NewData"
   FROM (systeme."T_Audit_Log" a
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = a."IdEntiteFk")));


--
-- Name: VIEW "V_Audit_log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Audit_log" IS 'Journal au grain événement. Les images avant/après masquent les champs de mot de passe et jetons, y compris pour les événements historiques. Les droits restent imposés par le service.';


--
-- Name: COLUMN "V_Audit_log"."IdLog"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."IdLog" IS 'Identifiant de l’événement d’audit. Expression projetée : a."IdLog".';


--
-- Name: COLUMN "V_Audit_log"."TableName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."TableName" IS 'Nom de la table à l’origine de l’événement d’audit. Expression projetée : a."TableName".';


--
-- Name: COLUMN "V_Audit_log"."Operation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."Operation" IS 'Nom de l’opération auditée ; le trigger produit INSERT, UPDATE ou DELETE. Expression projetée : a."Operation".';


--
-- Name: COLUMN "V_Audit_log"."ChangedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."ChangedAt" IS 'Horodatage de l’événement d’audit. Expression projetée : a."ChangedAt".';


--
-- Name: COLUMN "V_Audit_log"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';


--
-- Name: COLUMN "V_Audit_log"."OldData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."OldData" IS 'Image avant opération sans champs de mot de passe ni jetons ; NULL pour une insertion.';


--
-- Name: COLUMN "V_Audit_log"."NewData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."NewData" IS 'Image après opération sans champs de mot de passe ni jetons ; NULL pour une suppression.';


--
-- Name: V_Entite_Localisation_Detail; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Entite_Localisation_Detail" AS
 SELECT el."IdEntiteLocalisation",
    e."IdEntite",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    e."AdresseEntite",
    e."IdTypeEntiteFk",
    te."NomGenerique" AS "TypeEntite",
    el."Latitude",
    el."Longitude",
    el."AdresseDetaillee",
    el."DateCreation",
    el."IdNiveau_3_Fk",
    n3."NomNiveau_3",
    el."IdNiveau_4_Fk",
    n4."NomNiveau_4",
    el."IdNiveau_5_Fk",
    n5."NomNiveau_5"
   FROM (((((systeme."T_Entite" e
     LEFT JOIN systeme."T_Entite_Localisation" el ON ((el."IdEntiteFk" = e."IdEntite")))
     LEFT JOIN referentiel."T_Generique" te ON ((te."ID_Generique" = e."IdTypeEntiteFk")))
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n3."ID_Niveau_3" = el."IdNiveau_3_Fk")))
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n4."ID_Niveau_4" = el."IdNiveau_4_Fk")))
     LEFT JOIN geolocalisation."T_Niveau_5" n5 ON ((n5."ID_Niveau_5" = el."IdNiveau_5_Fk")));


--
-- Name: VIEW "V_Entite_Localisation_Detail"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Entite_Localisation_Detail" IS 'Entités enrichies de leurs localisations, type et niveaux géographiques. Grain entité/localisation ; une entité sans localisation reste présente et une entité peut apparaître sur plusieurs lignes.';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdEntiteLocalisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdEntiteLocalisation" IS 'Identifiant de la localisation d’entité. Expression projetée : el."IdEntiteLocalisation".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdEntite" IS 'Identifiant de l’entité. Expression projetée : e."IdEntite".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."PhoneEntite" IS 'Téléphone de contact de l’entité. Expression projetée : e."PhoneEntite".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."EmailEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."EmailEntite" IS 'Adresse électronique de contact de l’entité. Expression projetée : e."EmailEntite".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."AdresseEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."AdresseEntite" IS 'Adresse générale enregistrée pour l’entité. Expression projetée : e."AdresseEntite".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdTypeEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdTypeEntiteFk" IS 'Type de structure ou d’organisation dans le référentiel. Expression projetée : e."IdTypeEntiteFk".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."TypeEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."TypeEntite" IS 'Libellé du type d’entité dans le référentiel. Expression projetée : te."NomGenerique" AS "TypeEntite".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."Latitude"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."Latitude" IS 'Latitude de la localisation ; coordonnée décimale. Expression projetée : el."Latitude".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."Longitude"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."Longitude" IS 'Longitude de la localisation ; coordonnée décimale. Expression projetée : el."Longitude".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."AdresseDetaillee"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."AdresseDetaillee" IS 'Adresse détaillée de cette localisation. Expression projetée : el."AdresseDetaillee".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."DateCreation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."DateCreation" IS 'Date et heure de création de l’enregistrement. Expression projetée : el."DateCreation".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdNiveau_3_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdNiveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Expression projetée : el."IdNiveau_3_Fk".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."NomNiveau_3"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdNiveau_4_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdNiveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Expression projetée : el."IdNiveau_4_Fk".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."NomNiveau_4"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."NomNiveau_4" IS 'Nom de l’unité géographique de niveau 4. Expression projetée : n4."NomNiveau_4".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdNiveau_5_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdNiveau_5_Fk" IS 'Unité géographique de rattachement de niveau 5. Expression projetée : el."IdNiveau_5_Fk".';


--
-- Name: COLUMN "V_Entite_Localisation_Detail"."NomNiveau_5"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."NomNiveau_5" IS 'Nom de l’unité géographique de niveau 5. Expression projetée : n5."NomNiveau_5".';


--
-- Name: V_Entite_Public; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Entite_Public" AS
 SELECT e."IdEntite",
    e."NomEntite",
    e."PhoneEntite",
    e."AdresseEntite",
    e."ValideEntite",
    jsonb_build_object('ID_Generique', g."ID_Generique", 'NomGenerique', g."NomGenerique", 'AbrGenerique', g."AbrGenerique") AS "T_Generique"
   FROM (systeme."T_Entite" e
     LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = e."IdTypeEntiteFk")))
  WHERE (e."ValideEntite" = true);


--
-- Name: VIEW "V_Entite_Public"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Entite_Public" IS 'Annuaire public des structures actives au grain entité : nom, adresse et téléphone de structure, type ; aucune donnée de connexion utilisateur.';


--
-- Name: COLUMN "V_Entite_Public"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."IdEntite" IS 'Identifiant de l’entité.';


--
-- Name: COLUMN "V_Entite_Public"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."NomEntite" IS 'Nom de la structure ou organisation.';


--
-- Name: COLUMN "V_Entite_Public"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."PhoneEntite" IS 'Téléphone de contact de l’entité.';


--
-- Name: COLUMN "V_Entite_Public"."AdresseEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."AdresseEntite" IS 'Adresse générale enregistrée pour l’entité.';


--
-- Name: COLUMN "V_Entite_Public"."ValideEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."ValideEntite" IS 'Indique si l’entité est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "V_Entite_Public"."T_Generique"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."T_Generique" IS 'Type de structure sous forme JSON : identifiant, nom et abréviation du référentiel.';


--
-- Name: V_Fk_Correspondance; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Fk_Correspondance" AS
 SELECT fc."ModuleName",
    fc."SchemaName",
    fc."ViewName",
    fc."SourceKey",
    fc."FieldName",
    max((fc."FieldLabel")::text) AS "FieldLabel",
    fc."MappingType",
    max((fc."ReferenceSchemaName")::text) AS "ReferenceSchemaName",
    max((fc."ReferenceObjectName")::text) AS "ReferenceObjectName",
    max((fc."ReferenceFieldName")::text) AS "ReferenceFieldName",
    string_agg(DISTINCT (fc."MappingValue")::text, ', '::text ORDER BY (fc."MappingValue")::text) AS "MappingValues",
    string_agg(DISTINCT (c."NomCategorieGenerique")::text, ', '::text ORDER BY (c."NomCategorieGenerique")::text) AS "CategoryLabels",
    bool_or(fc."IsDefaultMapping") AS "HasDefaultMapping",
    bool_or(fc."ValideFkCorrespondance") AS "HasActiveMapping",
    fc."SettingScope",
    fc."ScopeValue",
    count(*) AS "NbCorrespondances",
    max(fc."UpdatedAt") AS "UpdatedAt"
   FROM (systeme."T_Fk_Correspondance" fc
     LEFT JOIN referentiel."T_CategorieGenerique" c ON ((c."ID_CategorieGenerique" = fc."TargetCategoryIdFk")))
  GROUP BY fc."ModuleName", fc."SchemaName", fc."ViewName", fc."SourceKey", fc."FieldName", fc."MappingType", fc."SettingScope", fc."ScopeValue";


--
-- Name: VIEW "V_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Fk_Correspondance" IS 'Synthèse des correspondances par module, schéma, vue, source, champ, type et portée : valeurs/catégories distinctes, indicateurs et compte. Les correspondances inactives restent incluses dans le regroupement.';


--
-- Name: COLUMN "V_Fk_Correspondance"."ModuleName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ModuleName" IS 'Module applicatif auquel s’applique la correspondance. Expression projetée : fc."ModuleName".';


--
-- Name: COLUMN "V_Fk_Correspondance"."SchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."SchemaName" IS 'Schéma PostgreSQL de la vue dont le champ est configuré. Expression projetée : fc."SchemaName".';


--
-- Name: COLUMN "V_Fk_Correspondance"."ViewName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ViewName" IS 'Nom de la vue dont les correspondances de champ sont configurées. Expression projetée : fc."ViewName".';


--
-- Name: COLUMN "V_Fk_Correspondance"."SourceKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."SourceKey" IS 'Clé applicative de la source de liste configurée. Expression projetée : fc."SourceKey".';


--
-- Name: COLUMN "V_Fk_Correspondance"."FieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."FieldName" IS 'Nom technique du champ dont la source de liste est configurée. Expression projetée : fc."FieldName".';


--
-- Name: COLUMN "V_Fk_Correspondance"."FieldLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."FieldLabel" IS 'Libellé du champ présenté dans le paramétrage des correspondances. Expression projetée : max(fc."FieldLabel"::text) AS "FieldLabel".';


--
-- Name: COLUMN "V_Fk_Correspondance"."MappingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."MappingType" IS 'Mode de correspondance : generic_category, direct_source ou hierarchy_mode, selon la contrainte installée. Expression projetée : fc."MappingType".';


--
-- Name: COLUMN "V_Fk_Correspondance"."ReferenceSchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ReferenceSchemaName" IS 'Schéma PostgreSQL de l’objet de référence configuré. Expression projetée : max(fc."ReferenceSchemaName"::text) AS "ReferenceSchemaName".';


--
-- Name: COLUMN "V_Fk_Correspondance"."ReferenceObjectName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ReferenceObjectName" IS 'Nom technique de l’objet de référence configuré pour la liste. Expression projetée : max(fc."ReferenceObjectName"::text) AS "ReferenceObjectName".';


--
-- Name: COLUMN "V_Fk_Correspondance"."ReferenceFieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ReferenceFieldName" IS 'Champ identifiant ou libellé utilisé dans l’objet de référence configuré. Expression projetée : max(fc."ReferenceFieldName"::text) AS "ReferenceFieldName".';


--
-- Name: COLUMN "V_Fk_Correspondance"."MappingValues"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."MappingValues" IS 'Valeurs de correspondance distinctes agrégées et triées, séparées par une virgule. Expression projetée : string_agg(DISTINCT fc."MappingValue"::text, '', ''::text ORDER BY (fc."MappingValue"::text)) AS "MappingValues".';


--
-- Name: COLUMN "V_Fk_Correspondance"."CategoryLabels"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."CategoryLabels" IS 'Libellés distincts des catégories cibles agrégés et triés. Expression projetée : string_agg(DISTINCT c."NomCategorieGenerique"::text, '', ''::text ORDER BY (c."NomCategorieGenerique"::text)) AS "CategoryLabels".';


--
-- Name: COLUMN "V_Fk_Correspondance"."HasDefaultMapping"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."HasDefaultMapping" IS 'Vrai si au moins une correspondance du groupe est marquée par défaut. Expression projetée : bool_or(fc."IsDefaultMapping") AS "HasDefaultMapping".';


--
-- Name: COLUMN "V_Fk_Correspondance"."HasActiveMapping"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."HasActiveMapping" IS 'Vrai si au moins une correspondance du groupe est déclarée valide. Expression projetée : bool_or(fc."ValideFkCorrespondance") AS "HasActiveMapping".';


--
-- Name: COLUMN "V_Fk_Correspondance"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."SettingScope" IS 'Niveau de portée du paramètre ou de la correspondance ; consulter la contrainte de la table pour les valeurs admises. Expression projetée : fc."SettingScope".';


--
-- Name: COLUMN "V_Fk_Correspondance"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès. Expression projetée : fc."ScopeValue".';


--
-- Name: COLUMN "V_Fk_Correspondance"."NbCorrespondances"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."NbCorrespondances" IS 'Nombre de lignes de correspondance dans ce groupe, y compris les inactives. Expression projetée : count(*) AS "NbCorrespondances".';


--
-- Name: COLUMN "V_Fk_Correspondance"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré. Expression projetée : max(fc."UpdatedAt") AS "UpdatedAt".';


--
-- Name: V_Fk_Correspondance_Audit; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Fk_Correspondance_Audit" AS
 SELECT "IdLog",
    "TableName",
    "Operation",
    "ChangedAt",
    COALESCE(("NewData" ->> 'settingScope'::text), ("OldData" ->> 'settingScope'::text), 'global'::text) AS "SettingScope",
    COALESCE(("NewData" ->> 'scopeValue'::text), ("OldData" ->> 'scopeValue'::text)) AS "ScopeValue",
    COALESCE(("NewData" ->> 'updatedByName'::text), ("OldData" ->> 'updatedByName'::text)) AS "UpdatedByName",
    COALESCE(("NewData" ->> 'updatedByUserId'::text), ("OldData" ->> 'updatedByUserId'::text)) AS "UpdatedByUserId",
    COALESCE(("NewData" ->> 'updatedAt'::text), ("OldData" ->> 'updatedAt'::text)) AS "UpdatedSettingAt",
    "OldData",
    "NewData"
   FROM systeme."T_Audit_Log" a
  WHERE ("TableName" = 'T_Fk_Correspondance'::text)
  ORDER BY "ChangedAt" DESC;


--
-- Name: VIEW "V_Fk_Correspondance_Audit"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Fk_Correspondance_Audit" IS 'Événements d’audit filtrés sur T_Fk_Correspondance ; contexte extrait des clés JSON applicatives en camelCase depuis NewData puis OldData. Grain événement ; pas de filtre d’accès intégré.';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."IdLog"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."IdLog" IS 'Identifiant de l’événement d’audit. Expression projetée : "IdLog".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."TableName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."TableName" IS 'Nom de la table à l’origine de l’événement d’audit. Expression projetée : "TableName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."Operation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."Operation" IS 'Nom de l’opération auditée ; le trigger produit INSERT, UPDATE ou DELETE. Expression projetée : "Operation".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."ChangedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."ChangedAt" IS 'Horodatage de l’événement d’audit. Expression projetée : "ChangedAt".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."SettingScope" IS 'Niveau de portée du paramètre ou de la correspondance ; consulter la contrainte de la table pour les valeurs admises. Expression projetée : COALESCE("NewData" ->> ''settingScope''::text, "OldData" ->> ''settingScope''::text, ''global''::text) AS "SettingScope".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès. Expression projetée : COALESCE("NewData" ->> ''scopeValue''::text, "OldData" ->> ''scopeValue''::text) AS "ScopeValue".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."UpdatedByName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedByName" IS 'Nom du dernier modificateur ; repli Utilisateur #identifiant lorsque le compte n’est pas résolu. Expression projetée : COALESCE("NewData" ->> ''updatedByName''::text, "OldData" ->> ''updatedByName''::text) AS "UpdatedByName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."UpdatedByUserId"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedByUserId" IS 'Identifiant du modificateur extrait du JSON d’audit applicatif ; représentation textuelle. Expression projetée : COALESCE("NewData" ->> ''updatedByUserId''::text, "OldData" ->> ''updatedByUserId''::text) AS "UpdatedByUserId".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."UpdatedSettingAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedSettingAt" IS 'Horodatage de modification extrait des clés JSON d’audit ; représentation textuelle. Expression projetée : COALESCE("NewData" ->> ''updatedAt''::text, "OldData" ->> ''updatedAt''::text) AS "UpdatedSettingAt".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."OldData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."OldData" IS 'Valeurs avant l’opération auditable, sérialisées en JSON ; NULL lors d’une insertion par le trigger d’audit. Expression projetée : "OldData".';


--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."NewData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."NewData" IS 'Valeurs après l’opération auditable, sérialisées en JSON ; NULL lors d’une suppression par le trigger d’audit. Expression projetée : "NewData".';


--
-- Name: V_Fk_Correspondance_Detail; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Fk_Correspondance_Detail" AS
 SELECT fc."IdFkCorrespondance",
    fc."ModuleName",
    fc."SchemaName",
    fc."ViewName",
    fc."SourceKey",
    fc."FieldName",
    fc."FieldLabel",
    fc."MappingType",
    fc."ReferenceSchemaName",
    fc."ReferenceObjectName",
    fc."ReferenceFieldName",
    fc."TargetCategoryIdFk",
    c."NomCategorieGenerique",
    fc."MappingValue",
    fc."IsDefaultMapping",
    fc."ValideFkCorrespondance",
    fc."SettingScope",
    fc."ScopeValue",
    fc."DisplayOrder",
    fc."UpdatedAt",
    fc."UpdatedByUserFk",
    COALESCE(NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text),
        CASE
            WHEN (fc."UpdatedByUserFk" IS NOT NULL) THEN ('Utilisateur #'::text || fc."UpdatedByUserFk")
            ELSE NULL::text
        END) AS "UpdatedByName",
    fc."ObsFkCorrespondance"
   FROM ((systeme."T_Fk_Correspondance" fc
     LEFT JOIN referentiel."T_CategorieGenerique" c ON ((c."ID_CategorieGenerique" = fc."TargetCategoryIdFk")))
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = fc."UpdatedByUserFk")));


--
-- Name: VIEW "V_Fk_Correspondance_Detail"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Fk_Correspondance_Detail" IS 'Correspondances de champs enrichies de la catégorie et du nom du dernier modificateur, au grain correspondance ; expose les portées et états sans filtrage de validité.';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."IdFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."IdFkCorrespondance" IS 'Identifiant de la correspondance de champ. Expression projetée : fc."IdFkCorrespondance".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ModuleName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ModuleName" IS 'Module applicatif auquel s’applique la correspondance. Expression projetée : fc."ModuleName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."SchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."SchemaName" IS 'Schéma PostgreSQL de la vue dont le champ est configuré. Expression projetée : fc."SchemaName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ViewName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ViewName" IS 'Nom de la vue dont les correspondances de champ sont configurées. Expression projetée : fc."ViewName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."SourceKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."SourceKey" IS 'Clé applicative de la source de liste configurée. Expression projetée : fc."SourceKey".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."FieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."FieldName" IS 'Nom technique du champ dont la source de liste est configurée. Expression projetée : fc."FieldName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."FieldLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."FieldLabel" IS 'Libellé du champ présenté dans le paramétrage des correspondances. Expression projetée : fc."FieldLabel".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."MappingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."MappingType" IS 'Mode de correspondance : generic_category, direct_source ou hierarchy_mode, selon la contrainte installée. Expression projetée : fc."MappingType".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ReferenceSchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ReferenceSchemaName" IS 'Schéma PostgreSQL de l’objet de référence configuré. Expression projetée : fc."ReferenceSchemaName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ReferenceObjectName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ReferenceObjectName" IS 'Nom technique de l’objet de référence configuré pour la liste. Expression projetée : fc."ReferenceObjectName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ReferenceFieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ReferenceFieldName" IS 'Champ identifiant ou libellé utilisé dans l’objet de référence configuré. Expression projetée : fc."ReferenceFieldName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."TargetCategoryIdFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."TargetCategoryIdFk" IS 'Catégorie de nomenclature ciblée par une correspondance de type generic_category. Expression projetée : fc."TargetCategoryIdFk".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."NomCategorieGenerique"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature. Expression projetée : c."NomCategorieGenerique".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."MappingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."MappingValue" IS 'Valeur de configuration associée à la correspondance. Expression projetée : fc."MappingValue".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."IsDefaultMapping"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."IsDefaultMapping" IS 'Indique une correspondance proposée par défaut. Expression projetée : fc."IsDefaultMapping".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ValideFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ValideFkCorrespondance" IS 'Indique si la correspondance est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : fc."ValideFkCorrespondance".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."SettingScope" IS 'Niveau de portée du paramètre ou de la correspondance ; consulter la contrainte de la table pour les valeurs admises. Expression projetée : fc."SettingScope".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès. Expression projetée : fc."ScopeValue".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."DisplayOrder"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."DisplayOrder" IS 'Ordre d’affichage du paramètre ou de la correspondance. Expression projetée : fc."DisplayOrder".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré. Expression projetée : fc."UpdatedAt".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."UpdatedByUserFk" IS 'Utilisateur ayant enregistré la dernière modification du paramètre ou de la correspondance. Expression projetée : fc."UpdatedByUserFk".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."UpdatedByName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."UpdatedByName" IS 'Nom du dernier modificateur ; repli Utilisateur #identifiant lorsque le compte n’est pas résolu. Expression projetée : COALESCE(NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''''::character varying), '' '', COALESCE(u."NomUser", ''''::character varying))), ''''::text), CASE WHEN fc."UpdatedByUserFk" IS NOT NULL THEN ''Utilisateur #''::text || fc."UpdatedByUserFk" ELSE NULL::text END) AS "UpdatedByName".';


--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ObsFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ObsFkCorrespondance" IS 'Observations enregistrées sur la correspondance. Expression projetée : fc."ObsFkCorrespondance".';


--
-- Name: V_Licence_active; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Licence_active" AS
 SELECT l."IdLicence",
    l."IdEntiteFk",
    e."NomEntite",
    l."DateDebut",
    l."DateFin",
    l."ValideLicence",
    (l."DateFin" <= CURRENT_TIMESTAMP) AS "ExpireeLicence",
        CASE
            WHEN (l."ValideLicence" IS NOT TRUE) THEN 'Inactive'::text
            WHEN (l."DateFin" <= CURRENT_TIMESTAMP) THEN 'Expirée'::text
            WHEN (l."DateDebut" > CURRENT_TIMESTAMP) THEN 'À venir'::text
            ELSE 'Active'::text
        END AS statut_licence
   FROM (systeme."T_Licence" l
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = l."IdEntiteFk")));


--
-- Name: VIEW "V_Licence_active"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Licence_active" IS 'Suivi de toutes les licences au grain licence ; état temporel calculé à chaque lecture : Inactive, Expirée, À venir ou Active. Le nom historique est conservé ; aucune licence historique n’est masquée.';


--
-- Name: COLUMN "V_Licence_active"."IdLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."IdLicence" IS 'Identifiant de la licence. Expression projetée : l."IdLicence".';


--
-- Name: COLUMN "V_Licence_active"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Expression projetée : l."IdEntiteFk".';


--
-- Name: COLUMN "V_Licence_active"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';


--
-- Name: COLUMN "V_Licence_active"."DateDebut"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."DateDebut" IS 'Début de la période enregistrée. Expression projetée : l."DateDebut".';


--
-- Name: COLUMN "V_Licence_active"."DateFin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."DateFin" IS 'Fin de la période enregistrée. Expression projetée : l."DateFin".';


--
-- Name: COLUMN "V_Licence_active"."ValideLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."ValideLicence" IS 'Indique si la licence est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : l."ValideLicence".';


--
-- Name: COLUMN "V_Licence_active"."ExpireeLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."ExpireeLicence" IS 'Vrai dès que DateFin est atteinte à l’instant de lecture, indépendamment du drapeau stocké.';


--
-- Name: COLUMN "V_Licence_active".statut_licence; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active".statut_licence IS 'Inactive si désactivée ; sinon Expirée à DateFin, À venir avant DateDebut, Active durant la période de validité.';


--
-- Name: V_Login_history; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Login_history" AS
 SELECT lg."IdLogin",
    lg."DateLogin",
    lg."IdTypeLoginFk",
    type_log."AbrGenerique" AS "TypeLogin",
    u."IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    e."IdEntite",
    e."NomEntite"
   FROM (((systeme."T_Login" lg
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = lg."IdUserFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = lg."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" type_log ON ((lg."IdTypeLoginFk" = type_log."ID_Generique")));


--
-- Name: VIEW "V_Login_history"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Login_history" IS 'Historique au grain événement de connexion, enrichi de l’utilisateur, du type et de l’entité de l’événement.';


--
-- Name: COLUMN "V_Login_history"."IdLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."IdLogin" IS 'Identifiant de l’événement de connexion. Expression projetée : lg."IdLogin".';


--
-- Name: COLUMN "V_Login_history"."DateLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."DateLogin" IS 'Date et heure de l’événement de connexion. Expression projetée : lg."DateLogin".';


--
-- Name: COLUMN "V_Login_history"."IdTypeLoginFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."IdTypeLoginFk" IS 'Type de l’événement de connexion dans le référentiel. Expression projetée : lg."IdTypeLoginFk".';


--
-- Name: COLUMN "V_Login_history"."TypeLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."TypeLogin" IS 'Abréviation du type d’événement de connexion. Expression projetée : type_log."AbrGenerique" AS "TypeLogin".';


--
-- Name: COLUMN "V_Login_history"."IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."IdUser" IS 'Identifiant du compte utilisateur. Expression projetée : u."IdUser".';


--
-- Name: COLUMN "V_Login_history"."NomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."NomUser" IS 'Nom de l’utilisateur. Expression projetée : u."NomUser".';


--
-- Name: COLUMN "V_Login_history"."PrenomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."PrenomUser" IS 'Prénom de l’utilisateur. Expression projetée : u."PrenomUser".';


--
-- Name: COLUMN "V_Login_history"."EmailUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion. Expression projetée : u."EmailUser".';


--
-- Name: COLUMN "V_Login_history"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."IdEntite" IS 'Identifiant de l’entité. Expression projetée : e."IdEntite".';


--
-- Name: COLUMN "V_Login_history"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';


--
-- Name: V_User_profil; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_User_profil" AS
 SELECT u."IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    u."PhoneUser",
    u."SexeUser",
    u."ValideUser",
    u."Is_staff",
    u."Is_Admin",
    u."DatecreationUser",
    e."IdEntite",
    e."NomEntite",
    e."EmailEntite",
    e."PhoneEntite"
   FROM (systeme."T_Utilisateurs" u
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = u."IdEntiteFk")));


--
-- Name: VIEW "V_User_profil"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_User_profil" IS 'Profil au grain utilisateur enrichi de l’entité : identité, contacts, validité et indicateurs staff/admin ; ne projette pas MotdepasseUser et ne filtre pas les utilisateurs inactifs.';


--
-- Name: COLUMN "V_User_profil"."IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."IdUser" IS 'Identifiant du compte utilisateur. Expression projetée : u."IdUser".';


--
-- Name: COLUMN "V_User_profil"."NomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."NomUser" IS 'Nom de l’utilisateur. Expression projetée : u."NomUser".';


--
-- Name: COLUMN "V_User_profil"."PrenomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."PrenomUser" IS 'Prénom de l’utilisateur. Expression projetée : u."PrenomUser".';


--
-- Name: COLUMN "V_User_profil"."EmailUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion. Expression projetée : u."EmailUser".';


--
-- Name: COLUMN "V_User_profil"."PhoneUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."PhoneUser" IS 'Téléphone utilisateur ; le trigger de normalisation conserve les chiffres sans interpréter le pays. Expression projetée : u."PhoneUser".';


--
-- Name: COLUMN "V_User_profil"."SexeUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."SexeUser" IS 'Code de sexe enregistré pour le compte ; la contrainte actuelle admet M ou F. Expression projetée : u."SexeUser".';


--
-- Name: COLUMN "V_User_profil"."ValideUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."ValideUser" IS 'Indique si le compte est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : u."ValideUser".';


--
-- Name: COLUMN "V_User_profil"."Is_staff"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."Is_staff" IS 'Indicateur de compte staff ; pris en compte par les contrôles actuels d’administration. Expression projetée : u."Is_staff".';


--
-- Name: COLUMN "V_User_profil"."Is_Admin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."Is_Admin" IS 'Indicateur de compte administrateur ; pris en compte par les contrôles actuels d’administration. Expression projetée : u."Is_Admin".';


--
-- Name: COLUMN "V_User_profil"."DatecreationUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."DatecreationUser" IS 'Date et heure de création du compte. Expression projetée : u."DatecreationUser".';


--
-- Name: COLUMN "V_User_profil"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."IdEntite" IS 'Identifiant de l’entité. Expression projetée : e."IdEntite".';


--
-- Name: COLUMN "V_User_profil"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';


--
-- Name: COLUMN "V_User_profil"."EmailEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."EmailEntite" IS 'Adresse électronique de contact de l’entité. Expression projetée : e."EmailEntite".';


--
-- Name: COLUMN "V_User_profil"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."PhoneEntite" IS 'Téléphone de contact de l’entité. Expression projetée : e."PhoneEntite".';


--
-- Name: T_Recherche T_Recherche_pkey; Type: CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_pkey" PRIMARY KEY ("IdRecherche");


--
-- Name: CONSTRAINT "T_Recherche_pkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_pkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : PRIMARY KEY ("IdRecherche")';


--
-- Name: T_Communication Pk_IdCommunication; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Pk_IdCommunication" PRIMARY KEY ("IdCommunication");


--
-- Name: CONSTRAINT "Pk_IdCommunication" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdCommunication" ON communication."T_Communication" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Communication". Définition : PRIMARY KEY ("IdCommunication").';


--
-- Name: T_Chat T_Chat_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "T_Chat_pkey" PRIMARY KEY ("IdChat");


--
-- Name: CONSTRAINT "T_Chat_pkey" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_pkey" ON communication."T_Chat" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Chat". Définition : PRIMARY KEY ("IdChat").';


--
-- Name: T_Discussion T_Discussion_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "T_Discussion_pkey" PRIMARY KEY ("IdDiscussion");


--
-- Name: CONSTRAINT "T_Discussion_pkey" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_pkey" ON communication."T_Discussion" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Discussion". Définition : PRIMARY KEY ("IdDiscussion").';


--
-- Name: T_Niveau_0 T_Niveau_0_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_0"
    ADD CONSTRAINT "T_Niveau_0_pkey" PRIMARY KEY ("ID_Niveau_0");


--
-- Name: CONSTRAINT "T_Niveau_0_pkey" ON "T_Niveau_0"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_0_pkey" ON geolocalisation."T_Niveau_0" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_0". Définition : PRIMARY KEY ("ID_Niveau_0").';


--
-- Name: T_Niveau_1_Old T_Niveau_1_Old_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_1_Old"
    ADD CONSTRAINT "T_Niveau_1_Old_pkey" PRIMARY KEY ("ID_Niveau_1_Old");


--
-- Name: CONSTRAINT "T_Niveau_1_Old_pkey" ON "T_Niveau_1_Old"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_Old_pkey" ON geolocalisation."T_Niveau_1_Old" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_1_Old". Définition : PRIMARY KEY ("ID_Niveau_1_Old").';


--
-- Name: T_Niveau_1 T_Niveau_1_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_1"
    ADD CONSTRAINT "T_Niveau_1_pkey" PRIMARY KEY ("ID_Niveau_1");


--
-- Name: CONSTRAINT "T_Niveau_1_pkey" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_1_pkey" ON geolocalisation."T_Niveau_1" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_1". Définition : PRIMARY KEY ("ID_Niveau_1").';


--
-- Name: T_Niveau_2 T_Niveau_2_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "T_Niveau_2_pkey" PRIMARY KEY ("ID_Niveau_2");


--
-- Name: CONSTRAINT "T_Niveau_2_pkey" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_2_pkey" ON geolocalisation."T_Niveau_2" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_2". Définition : PRIMARY KEY ("ID_Niveau_2").';


--
-- Name: T_Niveau_3 T_Niveau_3_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "T_Niveau_3_pkey" PRIMARY KEY ("ID_Niveau_3");


--
-- Name: CONSTRAINT "T_Niveau_3_pkey" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_3_pkey" ON geolocalisation."T_Niveau_3" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_3". Définition : PRIMARY KEY ("ID_Niveau_3").';


--
-- Name: T_Niveau_4 T_Niveau_4_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "T_Niveau_4_pkey" PRIMARY KEY ("ID_Niveau_4");


--
-- Name: CONSTRAINT "T_Niveau_4_pkey" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_4_pkey" ON geolocalisation."T_Niveau_4" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_4". Définition : PRIMARY KEY ("ID_Niveau_4").';


--
-- Name: T_Niveau_5 T_Niveau_5_pkey; Type: CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "T_Niveau_5_pkey" PRIMARY KEY ("ID_Niveau_5");


--
-- Name: CONSTRAINT "T_Niveau_5_pkey" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "T_Niveau_5_pkey" ON geolocalisation."T_Niveau_5" IS 'Clé primaire : identifie de manière unique chaque ligne dans "geolocalisation"."T_Niveau_5". Définition : PRIMARY KEY ("ID_Niveau_5").';


--
-- Name: T_Article T_Article_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "T_Article_pkey" PRIMARY KEY ("ID_Article");


--
-- Name: CONSTRAINT "T_Article_pkey" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_pkey" ON logistique."T_Article" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_Article". Définition : PRIMARY KEY ("ID_Article").';


--
-- Name: T_CommandeDetail T_CommandeDetail_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CommandeDetail"
    ADD CONSTRAINT "T_CommandeDetail_pkey" PRIMARY KEY ("ID_ArticleFk", "ID_CmdFk");


--
-- Name: CONSTRAINT "T_CommandeDetail_pkey" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_CommandeDetail_pkey" ON logistique."T_CommandeDetail" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_CommandeDetail". Définition : PRIMARY KEY ("ID_ArticleFk", "ID_CmdFk").';


--
-- Name: T_Commande T_Commande_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "T_Commande_pkey" PRIMARY KEY ("ID_Commande");


--
-- Name: CONSTRAINT "T_Commande_pkey" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Commande_pkey" ON logistique."T_Commande" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_Commande". Définition : PRIMARY KEY ("ID_Commande").';


--
-- Name: T_Mouvement T_Mouvement_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT "T_Mouvement_pkey" PRIMARY KEY ("ID_Mvt");


--
-- Name: CONSTRAINT "T_Mouvement_pkey" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Mouvement_pkey" ON logistique."T_Mouvement" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_Mouvement". Définition : PRIMARY KEY ("ID_Mvt").';


--
-- Name: T_Reglements T_Reglements_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT "T_Reglements_pkey" PRIMARY KEY ("ID_Reglement");


--
-- Name: CONSTRAINT "T_Reglements_pkey" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Reglements_pkey" ON logistique."T_Reglements" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_Reglements". Définition : PRIMARY KEY ("ID_Reglement").';


--
-- Name: T_Article uq_article_codeinterne; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT uq_article_codeinterne UNIQUE ("CodeArticleInterne");


--
-- Name: CONSTRAINT uq_article_codeinterne ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_article_codeinterne ON logistique."T_Article" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "logistique"."T_Article". Définition : UNIQUE ("CodeArticleInterne").';


--
-- Name: T_Commande uq_commande_codecmd; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT uq_commande_codecmd UNIQUE ("CodeCmd");


--
-- Name: CONSTRAINT uq_commande_codecmd ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_commande_codecmd ON logistique."T_Commande" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "logistique"."T_Commande". Définition : UNIQUE ("CodeCmd").';


--
-- Name: T_Commande uq_commande_codefacture; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT uq_commande_codefacture UNIQUE ("CodeFacture");


--
-- Name: CONSTRAINT uq_commande_codefacture ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_commande_codefacture ON logistique."T_Commande" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "logistique"."T_Commande". Définition : UNIQUE ("CodeFacture").';


--
-- Name: T_Paiement Pk_IdPaiement; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Pk_IdPaiement" PRIMARY KEY ("IdPaiement");


--
-- Name: CONSTRAINT "Pk_IdPaiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdPaiement" ON operations."T_Paiement" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Paiement". Définition : PRIMARY KEY ("IdPaiement").';


--
-- Name: T_Caisse T_Caisse_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "T_Caisse_pkey" PRIMARY KEY ("IdCaisse");


--
-- Name: CONSTRAINT "T_Caisse_pkey" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_pkey" ON operations."T_Caisse" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Caisse". Définition : PRIMARY KEY ("IdCaisse").';


--
-- Name: T_Paiement_Archive T_Paiement_Archive_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement_Archive"
    ADD CONSTRAINT "T_Paiement_Archive_pkey" PRIMARY KEY ("IdPaiementArchive");


--
-- Name: CONSTRAINT "T_Paiement_Archive_pkey" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_Archive_pkey" ON operations."T_Paiement_Archive" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Paiement_Archive". Définition : PRIMARY KEY ("IdPaiementArchive").';


--
-- Name: T_Caisse UQ_Entite_Devise; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "UQ_Entite_Devise" UNIQUE ("IdEntiteFk", "IdDeviseFk");


--
-- Name: CONSTRAINT "UQ_Entite_Devise" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "UQ_Entite_Devise" ON operations."T_Caisse" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "operations"."T_Caisse". Définition : UNIQUE ("IdEntiteFk", "IdDeviseFk").';


--
-- Name: T_Professionnel Pk_IdProfessionnel; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Pk_IdProfessionnel" PRIMARY KEY ("IdProfessionnel");


--
-- Name: CONSTRAINT "Pk_IdProfessionnel" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdProfessionnel" ON professionnel."T_Professionnel" IS 'Clé primaire : identifie de manière unique chaque ligne dans "professionnel"."T_Professionnel". Définition : PRIMARY KEY ("IdProfessionnel").';


--
-- Name: T_Professionnel_Entite Pk_Professionnel_Entite; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Pk_Professionnel_Entite" PRIMARY KEY ("IdProfessionnelFk", "IdEntiteFk");


--
-- Name: CONSTRAINT "Pk_Professionnel_Entite" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_Professionnel_Entite" ON professionnel."T_Professionnel_Entite" IS 'Clé primaire : identifie de manière unique chaque ligne dans "professionnel"."T_Professionnel_Entite". Définition : PRIMARY KEY ("IdProfessionnelFk", "IdEntiteFk").';


--
-- Name: T_Professionnel Uq_Prof_IdUser; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Uq_Prof_IdUser" UNIQUE ("IdUserFk");


--
-- Name: CONSTRAINT "Uq_Prof_IdUser" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Prof_IdUser" ON professionnel."T_Professionnel" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "professionnel"."T_Professionnel". Définition : UNIQUE ("IdUserFk").';


--
-- Name: T_Professionnel Uq_Prof_NumeroIdentification; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Uq_Prof_NumeroIdentification" UNIQUE ("NumeroIdentification");


--
-- Name: CONSTRAINT "Uq_Prof_NumeroIdentification" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Prof_NumeroIdentification" ON professionnel."T_Professionnel" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "professionnel"."T_Professionnel". Définition : UNIQUE ("NumeroIdentification").';


--
-- Name: T_Generique Pk_T_Generique; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_Generique"
    ADD CONSTRAINT "Pk_T_Generique" PRIMARY KEY ("ID_Generique");


--
-- Name: CONSTRAINT "Pk_T_Generique" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_T_Generique" ON referentiel."T_Generique" IS 'Clé primaire : identifie de manière unique chaque ligne dans "referentiel"."T_Generique". Définition : PRIMARY KEY ("ID_Generique").';


--
-- Name: T_CategorieGenerique T_CategorieGenerique_pkey; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_CategorieGenerique"
    ADD CONSTRAINT "T_CategorieGenerique_pkey" PRIMARY KEY ("ID_CategorieGenerique");


--
-- Name: CONSTRAINT "T_CategorieGenerique_pkey" ON "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_CategorieGenerique_pkey" ON referentiel."T_CategorieGenerique" IS 'Clé primaire : identifie de manière unique chaque ligne dans "referentiel"."T_CategorieGenerique". Définition : PRIMARY KEY ("ID_CategorieGenerique").';


--
-- Name: T_Admin_UI_Setting Pk_Admin_UI_Setting; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Admin_UI_Setting"
    ADD CONSTRAINT "Pk_Admin_UI_Setting" PRIMARY KEY ("IdAdminUISetting");


--
-- Name: CONSTRAINT "Pk_Admin_UI_Setting" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_Admin_UI_Setting" ON systeme."T_Admin_UI_Setting" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Admin_UI_Setting". Définition : PRIMARY KEY ("IdAdminUISetting").';


--
-- Name: T_Entite Pk_IdEntite; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite"
    ADD CONSTRAINT "Pk_IdEntite" PRIMARY KEY ("IdEntite");


--
-- Name: CONSTRAINT "Pk_IdEntite" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdEntite" ON systeme."T_Entite" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Entite". Définition : PRIMARY KEY ("IdEntite").';


--
-- Name: T_Entite_Localisation Pk_IdEntiteLocalisation; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Pk_IdEntiteLocalisation" PRIMARY KEY ("IdEntiteLocalisation");


--
-- Name: CONSTRAINT "Pk_IdEntiteLocalisation" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdEntiteLocalisation" ON systeme."T_Entite_Localisation" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Entite_Localisation". Définition : PRIMARY KEY ("IdEntiteLocalisation").';


--
-- Name: T_Licence Pk_IdLicence; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Licence"
    ADD CONSTRAINT "Pk_IdLicence" PRIMARY KEY ("IdLicence");


--
-- Name: CONSTRAINT "Pk_IdLicence" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdLicence" ON systeme."T_Licence" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Licence". Définition : PRIMARY KEY ("IdLicence").';


--
-- Name: T_Login Pk_IdLogin; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Login"
    ADD CONSTRAINT "Pk_IdLogin" PRIMARY KEY ("IdLogin");


--
-- Name: CONSTRAINT "Pk_IdLogin" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdLogin" ON systeme."T_Login" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Login". Définition : PRIMARY KEY ("IdLogin").';


--
-- Name: T_Utilisateurs Pk_IdUser; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT "Pk_IdUser" PRIMARY KEY ("IdUser");


--
-- Name: CONSTRAINT "Pk_IdUser" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdUser" ON systeme."T_Utilisateurs" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Utilisateurs". Définition : PRIMARY KEY ("IdUser").';


--
-- Name: T_Audit_Log T_Audit_Log_pkey; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Audit_Log"
    ADD CONSTRAINT "T_Audit_Log_pkey" PRIMARY KEY ("IdLog");


--
-- Name: CONSTRAINT "T_Audit_Log_pkey" ON "T_Audit_Log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Audit_Log_pkey" ON systeme."T_Audit_Log" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Audit_Log". Définition : PRIMARY KEY ("IdLog").';


--
-- Name: T_Entite T_Entite_EmailEntite_key; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite"
    ADD CONSTRAINT "T_Entite_EmailEntite_key" UNIQUE ("EmailEntite");


--
-- Name: CONSTRAINT "T_Entite_EmailEntite_key" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_EmailEntite_key" ON systeme."T_Entite" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Entite". Définition : UNIQUE ("EmailEntite").';


--
-- Name: T_Entite T_Entite_PhoneEntite_key; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite"
    ADD CONSTRAINT "T_Entite_PhoneEntite_key" UNIQUE ("PhoneEntite");


--
-- Name: CONSTRAINT "T_Entite_PhoneEntite_key" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_PhoneEntite_key" ON systeme."T_Entite" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Entite". Définition : UNIQUE ("PhoneEntite").';


--
-- Name: T_Fk_Correspondance T_Fk_Correspondance_pkey; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "T_Fk_Correspondance_pkey" PRIMARY KEY ("IdFkCorrespondance");


--
-- Name: CONSTRAINT "T_Fk_Correspondance_pkey" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_pkey" ON systeme."T_Fk_Correspondance" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Fk_Correspondance". Définition : PRIMARY KEY ("IdFkCorrespondance").';


--
-- Name: T_Fk_Correspondance UQ_FkCorrespondance_SourceValueScope; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" UNIQUE ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue");


--
-- Name: CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" ON systeme."T_Fk_Correspondance" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Fk_Correspondance". Définition : UNIQUE ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue").';


--
-- Name: T_Admin_UI_Setting Uq_Admin_UI_Setting_Key_Scope; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Admin_UI_Setting"
    ADD CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" UNIQUE ("SettingScope", "ScopeValue", "SettingKey");


--
-- Name: CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" ON systeme."T_Admin_UI_Setting" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Admin_UI_Setting". Définition : UNIQUE ("SettingScope", "ScopeValue", "SettingKey").';


--
-- Name: T_Utilisateurs utilisateurs_emailuser_key; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT utilisateurs_emailuser_key UNIQUE ("EmailUser");


--
-- Name: CONSTRAINT utilisateurs_emailuser_key ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT utilisateurs_emailuser_key ON systeme."T_Utilisateurs" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Utilisateurs". Définition : UNIQUE ("EmailUser").';


--
-- Name: INDEX "T_Recherche_pkey"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON INDEX analytics."T_Recherche_pkey" IS 'Index de contrainte ou accès : CREATE UNIQUE INDEX "T_Recherche_pkey" ON analytics."T_Recherche" USING btree ("IdRecherche")';


--
-- Name: idx_recherche_article_date; Type: INDEX; Schema: analytics; Owner: -
--

CREATE INDEX idx_recherche_article_date ON analytics."T_Recherche" USING btree ("ID_ArticleResultFk", "DateRecherche");


--
-- Name: INDEX idx_recherche_article_date; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON INDEX analytics.idx_recherche_article_date IS 'Index de contrainte ou accès : CREATE INDEX idx_recherche_article_date ON analytics."T_Recherche" USING btree ("ID_ArticleResultFk", "DateRecherche")';


--
-- Name: idx_recherche_user; Type: INDEX; Schema: analytics; Owner: -
--

CREATE INDEX idx_recherche_user ON analytics."T_Recherche" USING btree ("IdUserFk");


--
-- Name: INDEX idx_recherche_user; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON INDEX analytics.idx_recherche_user IS 'Index de contrainte ou accès : CREATE INDEX idx_recherche_user ON analytics."T_Recherche" USING btree ("IdUserFk")';


--
-- Name: INDEX "Pk_IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."Pk_IdCommunication" IS 'Index support de la clé primaire sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdCommunication" ON communication."T_Communication" USING btree ("IdCommunication").';


--
-- Name: INDEX "T_Chat_pkey"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."T_Chat_pkey" IS 'Index support de la clé primaire sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Chat_pkey" ON communication."T_Chat" USING btree ("IdChat").';


--
-- Name: INDEX "T_Discussion_pkey"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."T_Discussion_pkey" IS 'Index support de la clé primaire sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Discussion_pkey" ON communication."T_Discussion" USING btree ("IdDiscussion").';


--
-- Name: idx_chat_author; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_author ON communication."T_Chat" USING btree ("AuthorIdFk");


--
-- Name: INDEX idx_chat_author; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_author IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_author ON communication."T_Chat" USING btree ("AuthorIdFk").';


--
-- Name: idx_chat_author_idchat_desc; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_author_idchat_desc ON communication."T_Chat" USING btree ("AuthorIdFk", "IdChat" DESC);


--
-- Name: INDEX idx_chat_author_idchat_desc; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_author_idchat_desc IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_author_idchat_desc ON communication."T_Chat" USING btree ("AuthorIdFk", "IdChat" DESC).';


--
-- Name: idx_chat_discussion_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_discussion_date ON communication."T_Chat" USING btree ("IdDiscussionFk", "DateChat");


--
-- Name: INDEX idx_chat_discussion_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_discussion_date IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_discussion_date ON communication."T_Chat" USING btree ("IdDiscussionFk", "DateChat").';


--
-- Name: idx_chat_discussion_idchat; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_discussion_idchat ON communication."T_Chat" USING btree ("IdDiscussionFk", "IdChat");


--
-- Name: INDEX idx_chat_discussion_idchat; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_discussion_idchat IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_discussion_idchat ON communication."T_Chat" USING btree ("IdDiscussionFk", "IdChat").';


--
-- Name: idx_comm_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_date ON communication."T_Communication" USING btree ("DateCommunication");


--
-- Name: INDEX idx_comm_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_date IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_date ON communication."T_Communication" USING btree ("DateCommunication").';


--
-- Name: idx_comm_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_entite ON communication."T_Communication" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_comm_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_entite IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_entite ON communication."T_Communication" USING btree ("IdEntiteFk").';


--
-- Name: idx_comm_type; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_type ON communication."T_Communication" USING btree ("IdTypeCommunication");


--
-- Name: INDEX idx_comm_type; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_type IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_type ON communication."T_Communication" USING btree ("IdTypeCommunication").';


--
-- Name: idx_comm_user; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_user ON communication."T_Communication" USING btree ("IdUserFk");


--
-- Name: INDEX idx_comm_user; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_user IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_user ON communication."T_Communication" USING btree ("IdUserFk").';


--
-- Name: idx_comm_user_unread; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_user_unread ON communication."T_Communication" USING btree ("IdUserFk", "DateCommunication" DESC) WHERE ("LectureCommunication" = false);


--
-- Name: INDEX idx_comm_user_unread; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_user_unread IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_user_unread ON communication."T_Communication" USING btree ("IdUserFk", "DateCommunication" DESC) WHERE ("LectureCommunication" = false).';


--
-- Name: idx_discussion_dernier_message; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_dernier_message ON communication."T_Discussion" USING btree ("DernierMessageAt" DESC);


--
-- Name: INDEX idx_discussion_dernier_message; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_dernier_message IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_dernier_message ON communication."T_Discussion" USING btree ("DernierMessageAt" DESC).';


--
-- Name: idx_discussion_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_entite ON communication."T_Discussion" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_discussion_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_entite IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_entite ON communication."T_Discussion" USING btree ("IdEntiteFk").';


--
-- Name: idx_discussion_professionnel; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_professionnel ON communication."T_Discussion" USING btree ("IdProfessionnelFk");


--
-- Name: INDEX idx_discussion_professionnel; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_professionnel IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_professionnel ON communication."T_Discussion" USING btree ("IdProfessionnelFk").';


--
-- Name: idx_discussion_user_client; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_user_client ON communication."T_Discussion" USING btree ("IdUserClientFk");


--
-- Name: INDEX idx_discussion_user_client; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_user_client IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_user_client ON communication."T_Discussion" USING btree ("IdUserClientFk").';


--
-- Name: uq_discussion_client_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_discussion_client_entite ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdEntiteFk") WHERE ((("TypeDiscussion")::text = 'structure'::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdEntiteFk" IS NOT NULL));


--
-- Name: INDEX uq_discussion_client_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_discussion_client_entite IS 'Index d’unicité sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_discussion_client_entite ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdEntiteFk") WHERE ((("TypeDiscussion")::text = ''structure''::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdEntiteFk" IS NOT NULL)).';


--
-- Name: uq_discussion_client_expert; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_discussion_client_expert ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdProfessionnelFk") WHERE ((("TypeDiscussion")::text = 'expert'::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NOT NULL));


--
-- Name: INDEX uq_discussion_client_expert; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_discussion_client_expert IS 'Index d’unicité sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_discussion_client_expert ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdProfessionnelFk") WHERE ((("TypeDiscussion")::text = ''expert''::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NOT NULL)).';


--
-- Name: INDEX "T_Niveau_0_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_0_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_0". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_0_pkey" ON geolocalisation."T_Niveau_0" USING btree ("ID_Niveau_0").';


--
-- Name: T_Niveau_1_ID_Niveau_0_Fk_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_1_ID_Niveau_0_Fk_idx" ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_0_Fk");


--
-- Name: INDEX "T_Niveau_1_ID_Niveau_0_Fk_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_1_ID_Niveau_0_Fk_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_1". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_1_ID_Niveau_0_Fk_idx" ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_0_Fk").';


--
-- Name: INDEX "T_Niveau_1_Old_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_1_Old_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_1_Old". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_1_Old_pkey" ON geolocalisation."T_Niveau_1_Old" USING btree ("ID_Niveau_1_Old").';


--
-- Name: INDEX "T_Niveau_1_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_1_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_1". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_1_pkey" ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_1").';


--
-- Name: T_Niveau_2_ID_Niveau_1_FK_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_2_ID_Niveau_1_FK_idx" ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_1_FK");


--
-- Name: INDEX "T_Niveau_2_ID_Niveau_1_FK_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_2_ID_Niveau_1_FK_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_2_ID_Niveau_1_FK_idx" ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_1_FK").';


--
-- Name: INDEX "T_Niveau_2_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_2_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_2_pkey" ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_2").';


--
-- Name: T_Niveau_3_ID_Niveau_2_FK_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_3_ID_Niveau_2_FK_idx" ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_2_FK");


--
-- Name: INDEX "T_Niveau_3_ID_Niveau_2_FK_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_3_ID_Niveau_2_FK_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_3_ID_Niveau_2_FK_idx" ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_2_FK").';


--
-- Name: INDEX "T_Niveau_3_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_3_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_3_pkey" ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_3").';


--
-- Name: T_Niveau_4_ID_Niveau_3_Fk_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_4_ID_Niveau_3_Fk_idx" ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_3_Fk");


--
-- Name: INDEX "T_Niveau_4_ID_Niveau_3_Fk_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_4_ID_Niveau_3_Fk_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_4_ID_Niveau_3_Fk_idx" ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_3_Fk").';


--
-- Name: INDEX "T_Niveau_4_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_4_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_4_pkey" ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_4").';


--
-- Name: T_Niveau_5_ID_Niveau_3_Fk_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_5_ID_Niveau_3_Fk_idx" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_3_Fk");


--
-- Name: INDEX "T_Niveau_5_ID_Niveau_3_Fk_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_5_ID_Niveau_3_Fk_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_5_ID_Niveau_3_Fk_idx" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_3_Fk").';


--
-- Name: T_Niveau_5_ID_Niveau_4_Fk_idx; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX "T_Niveau_5_ID_Niveau_4_Fk_idx" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_4_Fk");


--
-- Name: INDEX "T_Niveau_5_ID_Niveau_4_Fk_idx"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_5_ID_Niveau_4_Fk_idx" IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "T_Niveau_5_ID_Niveau_4_Fk_idx" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_4_Fk").';


--
-- Name: INDEX "T_Niveau_5_pkey"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation."T_Niveau_5_pkey" IS 'Index support de la clé primaire sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Niveau_5_pkey" ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_5").';


--
-- Name: idx_n1_id_niveau0_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n1_id_niveau0_fk ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_0_Fk");


--
-- Name: INDEX idx_n1_id_niveau0_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n1_id_niveau0_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_1". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n1_id_niveau0_fk ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_0_Fk").';


--
-- Name: idx_n1_id_niveau1_old_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n1_id_niveau1_old_fk ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_1_Old_Fk");


--
-- Name: INDEX idx_n1_id_niveau1_old_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n1_id_niveau1_old_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_1". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n1_id_niveau1_old_fk ON geolocalisation."T_Niveau_1" USING btree ("ID_Niveau_1_Old_Fk").';


--
-- Name: idx_n2_id_niveau1_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_niveau1_fk ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_1_FK");


--
-- Name: INDEX idx_n2_id_niveau1_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_niveau1_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_niveau1_fk ON geolocalisation."T_Niveau_2" USING btree ("ID_Niveau_1_FK").';


--
-- Name: idx_n2_id_statusdeploi_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_statusdeploi_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_StatusDeploiFk");


--
-- Name: INDEX idx_n2_id_statusdeploi_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_statusdeploi_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_statusdeploi_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_StatusDeploiFk").';


--
-- Name: idx_n2_id_statutniveau2_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_statutniveau2_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_StatutNiveau_2");


--
-- Name: INDEX idx_n2_id_statutniveau2_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_statutniveau2_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_statutniveau2_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_StatutNiveau_2").';


--
-- Name: idx_n2_id_typeniveau2_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_typeniveau2_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_TypeNiveau_2_Fk");


--
-- Name: INDEX idx_n2_id_typeniveau2_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_typeniveau2_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_typeniveau2_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_TypeNiveau_2_Fk").';


--
-- Name: idx_n2_id_voieaccesdpsant_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n2_id_voieaccesdpsant_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_VoieAccesDPSANTFk");


--
-- Name: INDEX idx_n2_id_voieaccesdpsant_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n2_id_voieaccesdpsant_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_2". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n2_id_voieaccesdpsant_fk_ref ON geolocalisation."T_Niveau_2" USING btree ("ID_VoieAccesDPSANTFk").';


--
-- Name: idx_n3_id_niveau2_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_niveau2_fk ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_2_FK");


--
-- Name: INDEX idx_n3_id_niveau2_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_niveau2_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_niveau2_fk ON geolocalisation."T_Niveau_3" USING btree ("ID_Niveau_2_FK").';


--
-- Name: idx_n3_id_statutdeploie_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_statutdeploie_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_StatutDeploieFk");


--
-- Name: INDEX idx_n3_id_statutdeploie_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_statutdeploie_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_statutdeploie_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_StatutDeploieFk").';


--
-- Name: idx_n3_id_statutniveau3_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_statutniveau3_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_StatutNiveau_3_Fk");


--
-- Name: INDEX idx_n3_id_statutniveau3_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_statutniveau3_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_statutniveau3_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_StatutNiveau_3_Fk").';


--
-- Name: idx_n3_id_typeniveau2_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_typeniveau2_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_TypeNiveau_2_Fk");


--
-- Name: INDEX idx_n3_id_typeniveau2_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_typeniveau2_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_typeniveau2_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_TypeNiveau_2_Fk").';


--
-- Name: idx_n3_id_voieaccesantbcz_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_voieaccesantbcz_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_VoieAccesANTBCZFk");


--
-- Name: INDEX idx_n3_id_voieaccesantbcz_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_voieaccesantbcz_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_voieaccesantbcz_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_VoieAccesANTBCZFk").';


--
-- Name: idx_n3_id_voieaccesdpsbcz_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n3_id_voieaccesdpsbcz_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_VoieAccesDPSBCZFk");


--
-- Name: INDEX idx_n3_id_voieaccesdpsbcz_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n3_id_voieaccesdpsbcz_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_3". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n3_id_voieaccesdpsbcz_fk_ref ON geolocalisation."T_Niveau_3" USING btree ("ID_VoieAccesDPSBCZFk").';


--
-- Name: idx_n4_id_disporeseau_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_disporeseau_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_DispoReseauNiveau_4");


--
-- Name: INDEX idx_n4_id_disporeseau_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_disporeseau_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_disporeseau_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_DispoReseauNiveau_4").';


--
-- Name: idx_n4_id_niveau3_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_niveau3_fk ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_3_Fk");


--
-- Name: INDEX idx_n4_id_niveau3_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_niveau3_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_niveau3_fk ON geolocalisation."T_Niveau_4" USING btree ("ID_Niveau_3_Fk").';


--
-- Name: idx_n4_id_statutdeploiement_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_statutdeploiement_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_StatutDeploiementFk");


--
-- Name: INDEX idx_n4_id_statutdeploiement_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_statutdeploiement_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_statutdeploiement_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_StatutDeploiementFk").';


--
-- Name: idx_n4_id_statutniveau4_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_statutniveau4_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_StatutNiveau_4");


--
-- Name: INDEX idx_n4_id_statutniveau4_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_statutniveau4_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_statutniveau4_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_StatutNiveau_4").';


--
-- Name: idx_n4_id_typeniveau4_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_typeniveau4_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_TypeNiveau_4_Fk");


--
-- Name: INDEX idx_n4_id_typeniveau4_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_typeniveau4_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_typeniveau4_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_TypeNiveau_4_Fk").';


--
-- Name: idx_n4_id_voieacceszsa_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n4_id_voieacceszsa_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_VoieAccesZsASFk");


--
-- Name: INDEX idx_n4_id_voieacceszsa_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n4_id_voieacceszsa_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_4". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n4_id_voieacceszsa_fk_ref ON geolocalisation."T_Niveau_4" USING btree ("ID_VoieAccesZsASFk").';


--
-- Name: idx_n5_id_disporeseau_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_disporeseau_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_DispoReseauNiveau_5");


--
-- Name: INDEX idx_n5_id_disporeseau_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_disporeseau_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_disporeseau_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_DispoReseauNiveau_5").';


--
-- Name: idx_n5_id_niveau4_fk; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_niveau4_fk ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_4_Fk");


--
-- Name: INDEX idx_n5_id_niveau4_fk; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_niveau4_fk IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_niveau4_fk ON geolocalisation."T_Niveau_5" USING btree ("ID_Niveau_4_Fk").';


--
-- Name: idx_n5_id_statutdeploiement_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_statutdeploiement_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_StatutDeploiementFk");


--
-- Name: INDEX idx_n5_id_statutdeploiement_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_statutdeploiement_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_statutdeploiement_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_StatutDeploiementFk").';


--
-- Name: idx_n5_id_statutniveau5_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_statutniveau5_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_StatutNiveau_5");


--
-- Name: INDEX idx_n5_id_statutniveau5_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_statutniveau5_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_statutniveau5_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_StatutNiveau_5").';


--
-- Name: idx_n5_id_typeniveau5_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_typeniveau5_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeNiveau_5_Fk");


--
-- Name: INDEX idx_n5_id_typeniveau5_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_typeniveau5_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_typeniveau5_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeNiveau_5_Fk").';


--
-- Name: idx_n5_id_typetoit_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_typetoit_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeToitFk");


--
-- Name: INDEX idx_n5_id_typetoit_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_typetoit_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_typetoit_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_TypeToitFk").';


--
-- Name: idx_n5_id_voieaccessite_fk_ref; Type: INDEX; Schema: geolocalisation; Owner: -
--

CREATE INDEX idx_n5_id_voieaccessite_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_VoieAccesZsSiteFk");


--
-- Name: INDEX idx_n5_id_voieaccessite_fk_ref; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON INDEX geolocalisation.idx_n5_id_voieaccessite_fk_ref IS 'Index d’accès sur "geolocalisation"."T_Niveau_5". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_n5_id_voieaccessite_fk_ref ON geolocalisation."T_Niveau_5" USING btree ("ID_VoieAccesZsSiteFk").';


--
-- Name: INDEX "T_Article_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Article_pkey" IS 'Index support de la clé primaire sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Article_pkey" ON logistique."T_Article" USING btree ("ID_Article").';


--
-- Name: INDEX "T_CommandeDetail_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_CommandeDetail_pkey" IS 'Index support de la clé primaire sur "logistique"."T_CommandeDetail". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_CommandeDetail_pkey" ON logistique."T_CommandeDetail" USING btree ("ID_ArticleFk", "ID_CmdFk").';


--
-- Name: INDEX "T_Commande_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Commande_pkey" IS 'Index support de la clé primaire sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Commande_pkey" ON logistique."T_Commande" USING btree ("ID_Commande").';


--
-- Name: INDEX "T_Mouvement_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Mouvement_pkey" IS 'Index support de la clé primaire sur "logistique"."T_Mouvement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Mouvement_pkey" ON logistique."T_Mouvement" USING btree ("ID_Mvt").';


--
-- Name: INDEX "T_Reglements_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Reglements_pkey" IS 'Index support de la clé primaire sur "logistique"."T_Reglements". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Reglements_pkey" ON logistique."T_Reglements" USING btree ("ID_Reglement").';


--
-- Name: idx_article_categorie; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_categorie ON logistique."T_Article" USING btree ("ID_CategorieArticleFk");


--
-- Name: INDEX idx_article_categorie; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_categorie IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_categorie ON logistique."T_Article" USING btree ("ID_CategorieArticleFk").';


--
-- Name: idx_article_nom; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_nom ON logistique."T_Article" USING btree ("NomArticle");


--
-- Name: INDEX idx_article_nom; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_nom IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_nom ON logistique."T_Article" USING btree ("NomArticle").';


--
-- Name: idx_article_nom_trgm; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_nom_trgm ON logistique."T_Article" USING gin ("NomArticle" public.gin_trgm_ops);


--
-- Name: INDEX idx_article_nom_trgm; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_nom_trgm IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_nom_trgm ON logistique."T_Article" USING gin ("NomArticle" gin_trgm_ops).';


--
-- Name: idx_article_type; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_type ON logistique."T_Article" USING btree ("ID_TypeArticleFk");


--
-- Name: INDEX idx_article_type; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_type IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_type ON logistique."T_Article" USING btree ("ID_TypeArticleFk").';


--
-- Name: idx_article_unite; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_unite ON logistique."T_Article" USING btree ("ID_UniteFk");


--
-- Name: INDEX idx_article_unite; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_unite IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_unite ON logistique."T_Article" USING btree ("ID_UniteFk").';


--
-- Name: idx_cmd_client; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmd_client ON logistique."T_Commande" USING btree ("ID_ClientFk");


--
-- Name: INDEX idx_cmd_client; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmd_client IS 'Index d’accès sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmd_client ON logistique."T_Commande" USING btree ("ID_ClientFk").';


--
-- Name: idx_cmd_date; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmd_date ON logistique."T_Commande" USING btree ("DateCmd");


--
-- Name: INDEX idx_cmd_date; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmd_date IS 'Index d’accès sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmd_date ON logistique."T_Commande" USING btree ("DateCmd").';


--
-- Name: idx_cmd_type; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmd_type ON logistique."T_Commande" USING btree ("ID_TypeCmdFk");


--
-- Name: INDEX idx_cmd_type; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmd_type IS 'Index d’accès sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmd_type ON logistique."T_Commande" USING btree ("ID_TypeCmdFk").';


--
-- Name: idx_cmd_user; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmd_user ON logistique."T_Commande" USING btree ("ID_UserFk");


--
-- Name: INDEX idx_cmd_user; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmd_user IS 'Index d’accès sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmd_user ON logistique."T_Commande" USING btree ("ID_UserFk").';


--
-- Name: idx_cmddetail_article; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmddetail_article ON logistique."T_CommandeDetail" USING btree ("ID_ArticleFk");


--
-- Name: INDEX idx_cmddetail_article; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmddetail_article IS 'Index d’accès sur "logistique"."T_CommandeDetail". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmddetail_article ON logistique."T_CommandeDetail" USING btree ("ID_ArticleFk").';


--
-- Name: idx_cmddetail_cmd; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmddetail_cmd ON logistique."T_CommandeDetail" USING btree ("ID_CmdFk");


--
-- Name: INDEX idx_cmddetail_cmd; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmddetail_cmd IS 'Index d’accès sur "logistique"."T_CommandeDetail". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmddetail_cmd ON logistique."T_CommandeDetail" USING btree ("ID_CmdFk").';


--
-- Name: idx_mvt_article; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_mvt_article ON logistique."T_Mouvement" USING btree ("ID_ArticleFk");


--
-- Name: INDEX idx_mvt_article; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_mvt_article IS 'Index d’accès sur "logistique"."T_Mouvement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_mvt_article ON logistique."T_Mouvement" USING btree ("ID_ArticleFk").';


--
-- Name: idx_mvt_cmd; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_mvt_cmd ON logistique."T_Mouvement" USING btree ("ID_cmdFk");


--
-- Name: INDEX idx_mvt_cmd; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_mvt_cmd IS 'Index d’accès sur "logistique"."T_Mouvement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_mvt_cmd ON logistique."T_Mouvement" USING btree ("ID_cmdFk").';


--
-- Name: idx_reglement_client; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_reglement_client ON logistique."T_Reglements" USING btree ("ID_ClientFk");


--
-- Name: INDEX idx_reglement_client; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_reglement_client IS 'Index d’accès sur "logistique"."T_Reglements". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_reglement_client ON logistique."T_Reglements" USING btree ("ID_ClientFk").';


--
-- Name: idx_reglement_date; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_reglement_date ON logistique."T_Reglements" USING btree ("DateReglement");


--
-- Name: INDEX idx_reglement_date; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_reglement_date IS 'Index d’accès sur "logistique"."T_Reglements". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_reglement_date ON logistique."T_Reglements" USING btree ("DateReglement").';


--
-- Name: INDEX uq_article_codeinterne; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_article_codeinterne IS 'Index d’unicité sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_article_codeinterne ON logistique."T_Article" USING btree ("CodeArticleInterne").';


--
-- Name: INDEX uq_commande_codecmd; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_commande_codecmd IS 'Index d’unicité sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_commande_codecmd ON logistique."T_Commande" USING btree ("CodeCmd").';


--
-- Name: INDEX uq_commande_codefacture; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_commande_codefacture IS 'Index d’unicité sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_commande_codefacture ON logistique."T_Commande" USING btree ("CodeFacture").';


--
-- Name: uq_mouvement_ligne_commande; Type: INDEX; Schema: logistique; Owner: -
--

CREATE UNIQUE INDEX uq_mouvement_ligne_commande ON logistique."T_Mouvement" USING btree ("ID_cmdFk", "ID_ArticleFk") WHERE ("ID_cmdFk" IS NOT NULL);


--
-- Name: INDEX uq_mouvement_ligne_commande; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_mouvement_ligne_commande IS 'Un seul mouvement source par paire commande/article ; les ajustements d’article sans commande restent multiples.';


--
-- Name: INDEX "Pk_IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."Pk_IdPaiement" IS 'Index support de la clé primaire sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdPaiement" ON operations."T_Paiement" USING btree ("IdPaiement").';


--
-- Name: INDEX "T_Caisse_pkey"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."T_Caisse_pkey" IS 'Index support de la clé primaire sur "operations"."T_Caisse". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Caisse_pkey" ON operations."T_Caisse" USING btree ("IdCaisse").';


--
-- Name: INDEX "T_Paiement_Archive_pkey"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."T_Paiement_Archive_pkey" IS 'Index support de la clé primaire sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Paiement_Archive_pkey" ON operations."T_Paiement_Archive" USING btree ("IdPaiementArchive").';


--
-- Name: INDEX "UQ_Entite_Devise"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."UQ_Entite_Devise" IS 'Index d’unicité sur "operations"."T_Caisse". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "UQ_Entite_Devise" ON operations."T_Caisse" USING btree ("IdEntiteFk", "IdDeviseFk").';


--
-- Name: idx_fk_paiement_user; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_fk_paiement_user ON operations."T_Paiement" USING btree ("IdUserFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_fk_paiement_user; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_fk_paiement_user IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fk_paiement_user ON operations."T_Paiement" USING btree ("IdUserFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_paiement_archive_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_date ON operations."T_Paiement_Archive" USING btree ("DatePaiement");


--
-- Name: INDEX idx_paiement_archive_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_date IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_date ON operations."T_Paiement_Archive" USING btree ("DatePaiement").';


--
-- Name: idx_paiement_archive_entite; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_entite ON operations."T_Paiement_Archive" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_paiement_archive_entite; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_entite IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_entite ON operations."T_Paiement_Archive" USING btree ("IdEntiteFk").';


--
-- Name: idx_paiement_archive_idpaiement; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_idpaiement ON operations."T_Paiement_Archive" USING btree ("IdPaiement");


--
-- Name: INDEX idx_paiement_archive_idpaiement; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_idpaiement IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_idpaiement ON operations."T_Paiement_Archive" USING btree ("IdPaiement").';


--
-- Name: idx_paiement_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_date ON operations."T_Paiement" USING btree ("DatePaiement") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_paiement_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_date IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_date ON operations."T_Paiement" USING btree ("DatePaiement") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_paiement_devise; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_devise ON operations."T_Paiement" USING btree ("IdDeviseFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_paiement_devise; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_devise IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_devise ON operations."T_Paiement" USING btree ("IdDeviseFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_paiement_entite_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_entite_date ON operations."T_Paiement" USING btree ("IdEntiteFk", "DatePaiement");


--
-- Name: INDEX idx_paiement_entite_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_entite_date IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_entite_date ON operations."T_Paiement" USING btree ("IdEntiteFk", "DatePaiement").';


--
-- Name: idx_paiement_statut; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_statut ON operations."T_Paiement" USING btree ("IdStatutPaiementFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_paiement_statut; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_statut IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_statut ON operations."T_Paiement" USING btree ("IdStatutPaiementFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: INDEX "Pk_IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Pk_IdProfessionnel" IS 'Index support de la clé primaire sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdProfessionnel" ON professionnel."T_Professionnel" USING btree ("IdProfessionnel").';


--
-- Name: INDEX "Pk_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Pk_Professionnel_Entite" IS 'Index support de la clé primaire sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_Professionnel_Entite" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk", "IdEntiteFk").';


--
-- Name: Uq_ProfEnt_Principal_Par_Prof; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE UNIQUE INDEX "Uq_ProfEnt_Principal_Par_Prof" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk") WHERE ("EstPrincipal" IS TRUE);


--
-- Name: INDEX "Uq_ProfEnt_Principal_Par_Prof"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_ProfEnt_Principal_Par_Prof" IS 'Index d’unicité sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_ProfEnt_Principal_Par_Prof" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk") WHERE ("EstPrincipal" IS TRUE).';


--
-- Name: INDEX "Uq_Prof_IdUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_Prof_IdUser" IS 'Index d’unicité sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_Prof_IdUser" ON professionnel."T_Professionnel" USING btree ("IdUserFk").';


--
-- Name: INDEX "Uq_Prof_NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_Prof_NumeroIdentification" IS 'Index d’unicité sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_Prof_NumeroIdentification" ON professionnel."T_Professionnel" USING btree ("NumeroIdentification").';


--
-- Name: idx_prof_specialite; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_prof_specialite ON professionnel."T_Professionnel" USING btree ("IdSpecialiteFk");


--
-- Name: INDEX idx_prof_specialite; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_prof_specialite IS 'Index d’accès sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_prof_specialite ON professionnel."T_Professionnel" USING btree ("IdSpecialiteFk").';


--
-- Name: idx_prof_type; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_prof_type ON professionnel."T_Professionnel" USING btree ("IdTypeProfessionnelFk");


--
-- Name: INDEX idx_prof_type; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_prof_type IS 'Index d’accès sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_prof_type ON professionnel."T_Professionnel" USING btree ("IdTypeProfessionnelFk").';


--
-- Name: idx_profent_datedebut; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profent_datedebut ON professionnel."T_Professionnel_Entite" USING btree ("DateDebut");


--
-- Name: INDEX idx_profent_datedebut; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profent_datedebut IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profent_datedebut ON professionnel."T_Professionnel_Entite" USING btree ("DateDebut").';


--
-- Name: idx_profent_entite; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profent_entite ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_profent_entite; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profent_entite IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profent_entite ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk").';


--
-- Name: idx_profession_principal; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profession_principal ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk") WHERE ("EstPrincipal" = true);


--
-- Name: INDEX idx_profession_principal; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profession_principal IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profession_principal ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk") WHERE ("EstPrincipal" = true).';


--
-- Name: INDEX "Pk_T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."Pk_T_Generique" IS 'Index support de la clé primaire sur "referentiel"."T_Generique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_T_Generique" ON referentiel."T_Generique" USING btree ("ID_Generique").';


--
-- Name: INDEX "T_CategorieGenerique_pkey"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."T_CategorieGenerique_pkey" IS 'Index support de la clé primaire sur "referentiel"."T_CategorieGenerique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_CategorieGenerique_pkey" ON referentiel."T_CategorieGenerique" USING btree ("ID_CategorieGenerique").';


--
-- Name: idx_generique_id_categorie; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX idx_generique_id_categorie ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_generique_id_categorie; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.idx_generique_id_categorie IS 'Index d’accès sur "referentiel"."T_Generique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_generique_id_categorie ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: Idx_Admin_UI_Setting_Group; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_Group" ON systeme."T_Admin_UI_Setting" USING btree ("SettingGroup");


--
-- Name: INDEX "Idx_Admin_UI_Setting_Group"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_Group" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_Group" ON systeme."T_Admin_UI_Setting" USING btree ("SettingGroup").';


--
-- Name: Idx_Admin_UI_Setting_Key; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_Key" ON systeme."T_Admin_UI_Setting" USING btree ("SettingKey");


--
-- Name: INDEX "Idx_Admin_UI_Setting_Key"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_Key" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_Key" ON systeme."T_Admin_UI_Setting" USING btree ("SettingKey").';


--
-- Name: Idx_Admin_UI_Setting_Scope; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_Scope" ON systeme."T_Admin_UI_Setting" USING btree ("SettingScope", "ScopeValue");


--
-- Name: INDEX "Idx_Admin_UI_Setting_Scope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_Scope" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_Scope" ON systeme."T_Admin_UI_Setting" USING btree ("SettingScope", "ScopeValue").';


--
-- Name: Idx_Admin_UI_Setting_UpdatedAt; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_UpdatedAt" ON systeme."T_Admin_UI_Setting" USING btree ("UpdatedAt");


--
-- Name: INDEX "Idx_Admin_UI_Setting_UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_UpdatedAt" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_UpdatedAt" ON systeme."T_Admin_UI_Setting" USING btree ("UpdatedAt").';


--
-- Name: Idx_Admin_UI_Setting_Valide; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_Valide" ON systeme."T_Admin_UI_Setting" USING btree ("ValideSetting");


--
-- Name: INDEX "Idx_Admin_UI_Setting_Valide"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_Valide" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_Valide" ON systeme."T_Admin_UI_Setting" USING btree ("ValideSetting").';


--
-- Name: INDEX "Pk_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_Admin_UI_Setting" IS 'Index support de la clé primaire sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_Admin_UI_Setting" ON systeme."T_Admin_UI_Setting" USING btree ("IdAdminUISetting").';


--
-- Name: INDEX "Pk_IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdEntite" IS 'Index support de la clé primaire sur "systeme"."T_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdEntite" ON systeme."T_Entite" USING btree ("IdEntite").';


--
-- Name: INDEX "Pk_IdEntiteLocalisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdEntiteLocalisation" IS 'Index support de la clé primaire sur "systeme"."T_Entite_Localisation". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdEntiteLocalisation" ON systeme."T_Entite_Localisation" USING btree ("IdEntiteLocalisation").';


--
-- Name: INDEX "Pk_IdLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdLicence" IS 'Index support de la clé primaire sur "systeme"."T_Licence". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdLicence" ON systeme."T_Licence" USING btree ("IdLicence").';


--
-- Name: INDEX "Pk_IdLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdLogin" IS 'Index support de la clé primaire sur "systeme"."T_Login". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdLogin" ON systeme."T_Login" USING btree ("IdLogin").';


--
-- Name: INDEX "Pk_IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdUser" IS 'Index support de la clé primaire sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdUser" ON systeme."T_Utilisateurs" USING btree ("IdUser").';


--
-- Name: INDEX "T_Audit_Log_pkey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."T_Audit_Log_pkey" IS 'Index support de la clé primaire sur "systeme"."T_Audit_Log". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Audit_Log_pkey" ON systeme."T_Audit_Log" USING btree ("IdLog").';


--
-- Name: INDEX "T_Entite_EmailEntite_key"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."T_Entite_EmailEntite_key" IS 'Index d’unicité sur "systeme"."T_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Entite_EmailEntite_key" ON systeme."T_Entite" USING btree ("EmailEntite").';


--
-- Name: INDEX "T_Entite_PhoneEntite_key"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."T_Entite_PhoneEntite_key" IS 'Index d’unicité sur "systeme"."T_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Entite_PhoneEntite_key" ON systeme."T_Entite" USING btree ("PhoneEntite").';


--
-- Name: INDEX "T_Fk_Correspondance_pkey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."T_Fk_Correspondance_pkey" IS 'Index support de la clé primaire sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Fk_Correspondance_pkey" ON systeme."T_Fk_Correspondance" USING btree ("IdFkCorrespondance").';


--
-- Name: INDEX "UQ_FkCorrespondance_SourceValueScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."UQ_FkCorrespondance_SourceValueScope" IS 'Index d’unicité sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "UQ_FkCorrespondance_SourceValueScope" ON systeme."T_Fk_Correspondance" USING btree ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue").';


--
-- Name: INDEX "Uq_Admin_UI_Setting_Key_Scope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Uq_Admin_UI_Setting_Key_Scope" IS 'Index d’unicité sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_Admin_UI_Setting_Key_Scope" ON systeme."T_Admin_UI_Setting" USING btree ("SettingScope", "ScopeValue", "SettingKey").';


--
-- Name: idx_audit_changedat; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_audit_changedat ON systeme."T_Audit_Log" USING btree ("ChangedAt" DESC);


--
-- Name: INDEX idx_audit_changedat; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_audit_changedat IS 'Index d’accès sur "systeme"."T_Audit_Log". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_audit_changedat ON systeme."T_Audit_Log" USING btree ("ChangedAt" DESC).';


--
-- Name: idx_audit_log_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_audit_log_entite ON systeme."T_Audit_Log" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_audit_log_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_audit_log_entite IS 'Index d’accès sur "systeme"."T_Audit_Log". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_audit_log_entite ON systeme."T_Audit_Log" USING btree ("IdEntiteFk").';


--
-- Name: idx_entite_loc_coords; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_entite_loc_coords ON systeme."T_Entite_Localisation" USING btree ("Latitude", "Longitude");


--
-- Name: INDEX idx_entite_loc_coords; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_entite_loc_coords IS 'Index d’accès sur "systeme"."T_Entite_Localisation". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_entite_loc_coords ON systeme."T_Entite_Localisation" USING btree ("Latitude", "Longitude").';


--
-- Name: idx_entite_loc_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_entite_loc_entite ON systeme."T_Entite_Localisation" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_entite_loc_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_entite_loc_entite IS 'Index d’accès sur "systeme"."T_Entite_Localisation". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_entite_loc_entite ON systeme."T_Entite_Localisation" USING btree ("IdEntiteFk").';


--
-- Name: idx_entite_nom; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_entite_nom ON systeme."T_Entite" USING btree ("NomEntite");


--
-- Name: INDEX idx_entite_nom; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_entite_nom IS 'Index d’accès sur "systeme"."T_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_entite_nom ON systeme."T_Entite" USING btree ("NomEntite").';


--
-- Name: idx_fk_licence_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fk_licence_entite ON systeme."T_Licence" USING btree ("IdEntiteFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_fk_licence_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fk_licence_entite IS 'Index d’accès sur "systeme"."T_Licence". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fk_licence_entite ON systeme."T_Licence" USING btree ("IdEntiteFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_fk_licence_statut; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fk_licence_statut ON systeme."T_Licence" USING btree ("IdStatutLicenceFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_fk_licence_statut; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fk_licence_statut IS 'Index d’accès sur "systeme"."T_Licence". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fk_licence_statut ON systeme."T_Licence" USING btree ("IdStatutLicenceFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_fkcorrespondance_category; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fkcorrespondance_category ON systeme."T_Fk_Correspondance" USING btree ("TargetCategoryIdFk");


--
-- Name: INDEX idx_fkcorrespondance_category; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fkcorrespondance_category IS 'Index d’accès sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fkcorrespondance_category ON systeme."T_Fk_Correspondance" USING btree ("TargetCategoryIdFk").';


--
-- Name: idx_fkcorrespondance_scope; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fkcorrespondance_scope ON systeme."T_Fk_Correspondance" USING btree ("SettingScope", "ScopeValue");


--
-- Name: INDEX idx_fkcorrespondance_scope; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fkcorrespondance_scope IS 'Index d’accès sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fkcorrespondance_scope ON systeme."T_Fk_Correspondance" USING btree ("SettingScope", "ScopeValue").';


--
-- Name: idx_fkcorrespondance_source; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fkcorrespondance_source ON systeme."T_Fk_Correspondance" USING btree ("SchemaName", "ViewName", "SourceKey");


--
-- Name: INDEX idx_fkcorrespondance_source; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fkcorrespondance_source IS 'Index d’accès sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fkcorrespondance_source ON systeme."T_Fk_Correspondance" USING btree ("SchemaName", "ViewName", "SourceKey").';


--
-- Name: idx_fkcorrespondance_updatedby; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fkcorrespondance_updatedby ON systeme."T_Fk_Correspondance" USING btree ("UpdatedByUserFk");


--
-- Name: INDEX idx_fkcorrespondance_updatedby; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fkcorrespondance_updatedby IS 'Index d’accès sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fkcorrespondance_updatedby ON systeme."T_Fk_Correspondance" USING btree ("UpdatedByUserFk").';


--
-- Name: idx_login_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_login_entite ON systeme."T_Login" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_login_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_login_entite IS 'Index d’accès sur "systeme"."T_Login". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_login_entite ON systeme."T_Login" USING btree ("IdEntiteFk").';


--
-- Name: idx_login_type; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_login_type ON systeme."T_Login" USING btree ("IdTypeLoginFk");


--
-- Name: INDEX idx_login_type; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_login_type IS 'Index d’accès sur "systeme"."T_Login". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_login_type ON systeme."T_Login" USING btree ("IdTypeLoginFk").';


--
-- Name: idx_login_user_date; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_login_user_date ON systeme."T_Login" USING btree ("IdUserFk", "DateLogin");


--
-- Name: INDEX idx_login_user_date; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_login_user_date IS 'Index d’accès sur "systeme"."T_Login". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_login_user_date ON systeme."T_Login" USING btree ("IdUserFk", "DateLogin").';


--
-- Name: idx_user_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_user_entite ON systeme."T_Utilisateurs" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_user_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_user_entite IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_user_entite ON systeme."T_Utilisateurs" USING btree ("IdEntiteFk").';


--
-- Name: idx_utilisateur_date_creation; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_utilisateur_date_creation ON systeme."T_Utilisateurs" USING btree ("DatecreationUser") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_utilisateur_date_creation; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_utilisateur_date_creation IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_utilisateur_date_creation ON systeme."T_Utilisateurs" USING btree ("DatecreationUser") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_utilisateur_nom; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_utilisateur_nom ON systeme."T_Utilisateurs" USING btree ("NomUser", "PrenomUser") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_utilisateur_nom; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_utilisateur_nom IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_utilisateur_nom ON systeme."T_Utilisateurs" USING btree ("NomUser", "PrenomUser") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_utilisateur_phone; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_utilisateur_phone ON systeme."T_Utilisateurs" USING btree ("PhoneUser") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_utilisateur_phone; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_utilisateur_phone IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_utilisateur_phone ON systeme."T_Utilisateurs" USING btree ("PhoneUser") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_utilisateur_role; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_utilisateur_role ON systeme."T_Utilisateurs" USING btree ("IdRoleFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_utilisateur_role; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_utilisateur_role IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_utilisateur_role ON systeme."T_Utilisateurs" USING btree ("IdRoleFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: INDEX utilisateurs_emailuser_key; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.utilisateurs_emailuser_key IS 'Index d’unicité sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX utilisateurs_emailuser_key ON systeme."T_Utilisateurs" USING btree ("EmailUser").';


--
-- Name: T_Chat tr_00_lock_discussion_message; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_00_lock_discussion_message BEFORE INSERT OR DELETE OR UPDATE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_lock_discussion_message();


--
-- Name: TRIGGER tr_00_lock_discussion_message ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_00_lock_discussion_message ON communication."T_Chat" IS 'Verrou des discussions avant modification de leurs messages.';


--
-- Name: T_Chat tr_sync_dernier_message; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_sync_dernier_message AFTER INSERT OR DELETE OR UPDATE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_sync_dernier_message();


--
-- Name: TRIGGER tr_sync_dernier_message ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_sync_dernier_message ON communication."T_Chat" IS 'Synchronise la dernière activité avec les messages effectivement présents.';


--
-- Name: T_CommandeDetail tr_00_guard_commandedetail; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_00_guard_commandedetail BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_guard_commandedetail();


--
-- Name: TRIGGER tr_00_guard_commandedetail ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_00_guard_commandedetail ON logistique."T_CommandeDetail" IS 'BEFORE ROW : verrouille les parents et contrôle leur clôture avant la mutation de ligne et ses effets stock.';


--
-- Name: T_Article tr_crud_article_after; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_article_after AFTER INSERT OR UPDATE ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_article_after();


--
-- Name: TRIGGER tr_crud_article_after ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_article_after ON logistique."T_Article" IS 'AFTER INSERT OR UPDATE sur "logistique"."T_Article", pour chaque ligne. Appelle "logistique"."tr_crud_article_after" : Après INSERT/UPDATE d’article, historise le stock initial non nul ou le delta direct en mouvement sans commande, valorisé avec PVArticle. Refuse les deltas fractionnaires ; le drapeau transactionnel skip_article_report_mvt évite le double report depuis les lignes.';


--
-- Name: T_Article tr_crud_article_before; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_article_before BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_article_before();


--
-- Name: TRIGGER tr_crud_article_before ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_article_before ON logistique."T_Article" IS 'BEFORE INSERT OR DELETE OR UPDATE sur "logistique"."T_Article", pour chaque ligne. Appelle "logistique"."tr_crud_article_before" : Avant INSERT/UPDATE, normalise la quantité absente à zéro et appelle ps_crud_article. Avant DELETE, bloque la suppression d’un article lié à une ligne ou un mouvement.';


--
-- Name: T_Commande tr_crud_commande; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_commande AFTER INSERT OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_commande();


--
-- Name: TRIGGER tr_crud_commande ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_commande ON logistique."T_Commande" IS 'AFTER INSERT OR UPDATE sur "logistique"."T_Commande", pour chaque ligne. Appelle "logistique"."tr_crud_commande" : Fonction de trigger AFTER INSERT/UPDATE transmettant anciens/nouveaux types et références à ps_crud_commande pour validation et réalignement des effets de stock.';


--
-- Name: T_CommandeDetail tr_crud_commandedetail; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_commandedetail AFTER INSERT OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_commandedetail();


--
-- Name: TRIGGER tr_crud_commandedetail ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_commandedetail ON logistique."T_CommandeDetail" IS 'AFTER INSERT OR UPDATE sur "logistique"."T_CommandeDetail", pour chaque ligne. Appelle "logistique"."tr_crud_commandedetail" : Fonction commune des triggers de ligne : transmet OLD/NEW à ps_crud_commandedetail. Raccordée après INSERT/UPDATE et avant DELETE pour annuler l’ancien effet avant disparition de la ligne.';


--
-- Name: T_Reglements tr_crud_reglement; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_reglement BEFORE INSERT OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_reglement();


--
-- Name: TRIGGER tr_crud_reglement ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_reglement ON logistique."T_Reglements" IS 'BEFORE INSERT OR UPDATE sur "logistique"."T_Reglements", pour chaque ligne. Appelle "logistique"."tr_crud_reglement" : Fonction de trigger BEFORE INSERT/UPDATE validant le mode via ps_crud_reglement ; renvoie la ligne sans mise à jour des montants de facture.';


--
-- Name: T_CommandeDetail tr_delete_commandedetail; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_delete_commandedetail BEFORE DELETE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_commandedetail();


--
-- Name: TRIGGER tr_delete_commandedetail ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_delete_commandedetail ON logistique."T_CommandeDetail" IS 'BEFORE DELETE sur "logistique"."T_CommandeDetail", pour chaque ligne. Appelle "logistique"."tr_crud_commandedetail" : Fonction commune des triggers de ligne : transmet OLD/NEW à ps_crud_commandedetail. Raccordée après INSERT/UPDATE et avant DELETE pour annuler l’ancien effet avant disparition de la ligne.';


--
-- Name: T_Commande tr_lock_commande_cloturee; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_lock_commande_cloturee BEFORE DELETE OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_lock_commande_cloturee();


--
-- Name: TRIGGER tr_lock_commande_cloturee ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_lock_commande_cloturee ON logistique."T_Commande" IS 'BEFORE DELETE OR UPDATE sur "logistique"."T_Commande", pour chaque ligne. Appelle "logistique"."tr_lock_commande_cloturee" : Avant UPDATE/DELETE de commande, refuse l’opération si OLD.StatusFacture vaut exactement Clôturée. La comparaison actuelle ne normalise pas la casse ou les variantes de libellé.';


--
-- Name: T_Mouvement tr_lock_mouvement_direct; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_lock_mouvement_direct BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_lock_mouvement_direct();


--
-- Name: TRIGGER tr_lock_mouvement_direct ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_lock_mouvement_direct ON logistique."T_Mouvement" IS 'BEFORE INSERT OR DELETE OR UPDATE sur "logistique"."T_Mouvement", pour chaque ligne. Appelle "logistique"."tr_lock_mouvement_direct" : Bloque les écritures sur T_Mouvement sauf si le drapeau transactionnel logistique.allow_t_mouvement_write vaut on ; valide alors la catégorie 64 du type pour INSERT/UPDATE.';


--
-- Name: T_CommandeDetail tr_totaux_commande_delete; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_totaux_commande_delete AFTER DELETE ON logistique."T_CommandeDetail" REFERENCING OLD TABLE AS lignes_anciennes FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();


--
-- Name: TRIGGER tr_totaux_commande_delete ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_totaux_commande_delete ON logistique."T_CommandeDetail" IS 'AFTER DELETE STATEMENT : recalcule les commandes distinctes des lignes supprimées ; tolère le parent déjà supprimé en cascade.';


--
-- Name: T_CommandeDetail tr_totaux_commande_insert; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_totaux_commande_insert AFTER INSERT ON logistique."T_CommandeDetail" REFERENCING NEW TABLE AS lignes_nouvelles FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();


--
-- Name: TRIGGER tr_totaux_commande_insert ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_totaux_commande_insert ON logistique."T_CommandeDetail" IS 'AFTER INSERT STATEMENT : recalcule les commandes distinctes de lignes_nouvelles, après les effets stock de chaque ligne.';


--
-- Name: T_CommandeDetail tr_totaux_commande_update; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_totaux_commande_update AFTER UPDATE ON logistique."T_CommandeDetail" REFERENCING OLD TABLE AS lignes_anciennes NEW TABLE AS lignes_nouvelles FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();


--
-- Name: TRIGGER tr_totaux_commande_update ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_totaux_commande_update ON logistique."T_CommandeDetail" IS 'AFTER UPDATE STATEMENT : recalcule les commandes distinctes des anciennes et nouvelles lignes ; une commande est recalculée au plus une fois par instruction.';


--
-- Name: T_Paiement trigger_archive_paiements; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_archive_paiements AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH STATEMENT EXECUTE FUNCTION operations.archive_paiements();

ALTER TABLE operations."T_Paiement" DISABLE TRIGGER trigger_archive_paiements;


--
-- Name: TRIGGER trigger_archive_paiements ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_archive_paiements ON operations."T_Paiement" IS 'AFTER INSERT OR UPDATE sur "operations"."T_Paiement", par instruction. Appelle "operations"."archive_paiements" : Après INSERT/UPDATE sur T_Paiement, copie les paiements âgés de plus de deux ans dans T_Paiement_Archive, puis les supprime de la table active. Déclenchement par instruction, sans planification périodique ; les triggers de suppression de la table active restent applicables.';


--
-- Name: T_Paiement trigger_audit_T_Paiement; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER "trigger_audit_T_Paiement" AFTER INSERT OR DELETE OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION systeme.audit_log_function();


--
-- Name: TRIGGER "trigger_audit_T_Paiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_Paiement" ON operations."T_Paiement" IS 'AFTER INSERT OR DELETE OR UPDATE sur "operations"."T_Paiement", pour chaque ligne. Appelle "systeme"."audit_log_function" : Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';


--
-- Name: T_Paiement trigger_gestion_caisse_on_paiement; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_gestion_caisse_on_paiement AFTER INSERT OR DELETE OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.gestion_caisse_on_paiement();


--
-- Name: TRIGGER trigger_gestion_caisse_on_paiement ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_gestion_caisse_on_paiement ON operations."T_Paiement" IS 'AFTER INSERT OR DELETE OR UPDATE sur "operations"."T_Paiement", pour chaque ligne. Appelle "operations"."gestion_caisse_on_paiement" : Après mutation d’un paiement, annule l’effet OLD et applique NEW dans la caisse entité/devise par UPSERT. Éligibilité : ValidePaiement vrai, statut Payé(e), catégorie devise, type de mouvement paiement Entrée/Sortie et entité renseignée. Les libellés de référentiel sont utilisés, contrairement aux codes fixes des fonctions d’audit.';


--
-- Name: T_Paiement trigger_notification_payment_success; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_notification_payment_success AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.notification_payment_success();


--
-- Name: TRIGGER trigger_notification_payment_success ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_notification_payment_success ON operations."T_Paiement" IS 'AFTER INSERT OR UPDATE sur "operations"."T_Paiement", pour chaque ligne. Appelle "operations"."notification_payment_success" : Après INSERT/UPDATE du paiement, ajoute une communication à son utilisateur si le libellé de statut n’est pas En attente. Ne vérifie pas une transition vers payé ni l’absence d’une notification précédente ; le nom de la fonction ne certifie pas un paiement réussi.';


--
-- Name: T_Caisse trigger_prevention_delete_caisse; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_prevention_delete_caisse BEFORE DELETE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION operations.prevent_delete_caisse_if_dependent();


--
-- Name: TRIGGER trigger_prevention_delete_caisse ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_prevention_delete_caisse ON operations."T_Caisse" IS 'BEFORE DELETE sur "operations"."T_Caisse", pour chaque ligne. Appelle "operations"."prevent_delete_caisse_if_dependent" : Avant DELETE de caisse, bloque la suppression s’il existe un paiement actif ou archivé pour le même couple entité/devise.';


--
-- Name: T_Generique tr_guard_sens_stock; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER tr_guard_sens_stock BEFORE UPDATE ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION referentiel.fn_guard_sens_stock();


--
-- Name: TRIGGER tr_guard_sens_stock ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER tr_guard_sens_stock ON referentiel."T_Generique" IS 'Empêche qu’une modification du référentiel inverse ou efface le sens d’un historique de stock existant.';


--
-- Name: T_Admin_UI_Setting tr_admin_ui_setting_set_updated_at; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER tr_admin_ui_setting_set_updated_at BEFORE UPDATE ON systeme."T_Admin_UI_Setting" FOR EACH ROW EXECUTE FUNCTION systeme.fn_admin_ui_setting_set_updated_at();


--
-- Name: TRIGGER tr_admin_ui_setting_set_updated_at ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER tr_admin_ui_setting_set_updated_at ON systeme."T_Admin_UI_Setting" IS 'BEFORE UPDATE sur "systeme"."T_Admin_UI_Setting", pour chaque ligne. Appelle "systeme"."fn_admin_ui_setting_set_updated_at" : Avant UPDATE d’un paramètre d’interface, remplace UpdatedAt par CURRENT_TIMESTAMP et renvoie NEW.';


--
-- Name: T_Login trigger_audit_T_Login; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER "trigger_audit_T_Login" AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Login" FOR EACH ROW EXECUTE FUNCTION systeme.audit_log_function();


--
-- Name: TRIGGER "trigger_audit_T_Login" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_Login" ON systeme."T_Login" IS 'AFTER INSERT OR DELETE OR UPDATE sur "systeme"."T_Login", pour chaque ligne. Appelle "systeme"."audit_log_function" : Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';


--
-- Name: T_Utilisateurs trigger_audit_T_Utilisateurs; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER "trigger_audit_T_Utilisateurs" AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.audit_log_function();


--
-- Name: TRIGGER "trigger_audit_T_Utilisateurs" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_Utilisateurs" ON systeme."T_Utilisateurs" IS 'AFTER INSERT OR DELETE OR UPDATE sur "systeme"."T_Utilisateurs", pour chaque ligne. Appelle "systeme"."audit_log_function" : Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';


--
-- Name: T_Licence trigger_audit_log_T_Licence; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER "trigger_audit_log_T_Licence" AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.audit_log_function();


--
-- Name: TRIGGER "trigger_audit_log_T_Licence" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_log_T_Licence" ON systeme."T_Licence" IS 'AFTER INSERT OR DELETE OR UPDATE sur "systeme"."T_Licence", pour chaque ligne. Appelle "systeme"."audit_log_function" : Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';


--
-- Name: T_Utilisateurs trigger_format_phone_number; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_format_phone_number BEFORE INSERT OR UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.format_phone_number();


--
-- Name: TRIGGER trigger_format_phone_number ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_format_phone_number ON systeme."T_Utilisateurs" IS 'BEFORE INSERT OR UPDATE sur "systeme"."T_Utilisateurs", pour chaque ligne. Appelle "systeme"."format_phone_number" : Avant INSERT/UPDATE d’un utilisateur, retire de PhoneUser tous les caractères autres que les chiffres. Ne normalise pas le préfixe international ni la validité téléphonique.';


--
-- Name: T_Licence trigger_notify_licence_expiry; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_notify_licence_expiry AFTER INSERT OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.notify_licence_expiry();


--
-- Name: TRIGGER trigger_notify_licence_expiry ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_notify_licence_expiry ON systeme."T_Licence" IS 'AFTER INSERT OR UPDATE sur "systeme"."T_Licence", pour chaque ligne. Appelle "systeme"."notify_licence_expiry" : Après INSERT/UPDATE de licence, crée une notification pour un administrateur d’entité si DATE_PART(day, DateFin - NOW()) vaut 7 et si destinataire/type Notification sont trouvés. Ce trigger n’est pas une tâche quotidienne et ne s’exécute pas du seul fait du passage du temps.';


--
-- Name: T_Licence trigger_prevent_multiple_licenses; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_prevent_multiple_licenses BEFORE INSERT OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.prevent_multiple_active_licenses();


--
-- Name: TRIGGER trigger_prevent_multiple_licenses ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_prevent_multiple_licenses ON systeme."T_Licence" IS 'Contrôle des périodes concurrentes de licences valides après verrouillage de leur entité.';


--
-- Name: T_Utilisateurs trigger_prevention_delete_utilisateur; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_prevention_delete_utilisateur BEFORE DELETE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.prevention_delete_if_dependent();


--
-- Name: TRIGGER trigger_prevention_delete_utilisateur ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_prevention_delete_utilisateur ON systeme."T_Utilisateurs" IS 'BEFORE DELETE sur "systeme"."T_Utilisateurs", pour chaque ligne. Appelle "systeme"."prevention_delete_if_dependent" : Avant DELETE utilisateur, bloque la suppression si des paiements liés par IdUserFk ou des présences/évaluations liées existent dans les tables que la fonction trouve. Ne couvre pas à elle seule toutes les dépendances : les contraintes FK restent applicables.';


--
-- Name: T_Utilisateurs trigger_update_date_modification; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_update_date_modification BEFORE UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.update_date_modification();


--
-- Name: TRIGGER trigger_update_date_modification ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_update_date_modification ON systeme."T_Utilisateurs" IS 'BEFORE UPDATE sur "systeme"."T_Utilisateurs", pour chaque ligne. Appelle "systeme"."update_date_modification" : Avant UPDATE utilisateur, remplace DateModificationUser par NOW() et renvoie NEW.';


--
-- Name: T_Licence trigger_update_licence_status; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_update_licence_status BEFORE INSERT OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.update_licence_status();


--
-- Name: TRIGGER trigger_update_licence_status ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_update_licence_status ON systeme."T_Licence" IS 'BEFORE INSERT OR UPDATE sur "systeme"."T_Licence", pour chaque ligne. Appelle "systeme"."update_licence_status" : Avant INSERT/UPDATE de licence, fixe ExpireeLicence selon DateFin < NOW() ; une date NULL suit la branche false. Aucun recalcul périodique indépendant d’une écriture.';


--
-- Name: T_Recherche T_Recherche_ID_ArticleResultFk_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_ID_ArticleResultFk_fkey" FOREIGN KEY ("ID_ArticleResultFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "T_Recherche_ID_ArticleResultFk_fkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_ID_ArticleResultFk_fkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : FOREIGN KEY ("ID_ArticleResultFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE ON DELETE SET NULL';


--
-- Name: T_Recherche T_Recherche_IdEntiteResultFk_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_IdEntiteResultFk_fkey" FOREIGN KEY ("IdEntiteResultFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "T_Recherche_IdEntiteResultFk_fkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_IdEntiteResultFk_fkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : FOREIGN KEY ("IdEntiteResultFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL';


--
-- Name: T_Recherche T_Recherche_IdSpecialiteFk_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_IdSpecialiteFk_fkey" FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "T_Recherche_IdSpecialiteFk_fkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_IdSpecialiteFk_fkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL';


--
-- Name: T_Recherche T_Recherche_IdUserFk_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_IdUserFk_fkey" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "T_Recherche_IdUserFk_fkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_IdUserFk_fkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL';


--
-- Name: T_Chat AuthorIdFk; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "AuthorIdFk" FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: CONSTRAINT "AuthorIdFk" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "AuthorIdFk" ON communication."T_Chat" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Chat". Définition : FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL.';


--
-- Name: T_Chat Fk_Chat_Discussion; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "Fk_Chat_Discussion" FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_Chat_Discussion" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Chat_Discussion" ON communication."T_Chat" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Chat". Définition : FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: T_Discussion Fk_Discussion_Entite; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Discussion_Entite" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_Entite" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Discussion Fk_Discussion_Professionnel; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_Professionnel" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Discussion_Professionnel" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_Professionnel" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Discussion Fk_Discussion_UserClient; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_UserClient" FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Discussion_UserClient" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_UserClient" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Communication Fk_IdEntite; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Communication Fk_IdTypeCommunication; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdTypeCommunication" FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdTypeCommunication" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdTypeCommunication" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Communication Fk_IdUser; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdUser" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdUser" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdUser" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Niveau_4 Fk_ID_DispoReseauNiveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_DispoReseauNiveau_4" FOREIGN KEY ("ID_DispoReseauNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_DispoReseauNiveau_4" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_DispoReseauNiveau_4" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_DispoReseauNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_5 Fk_ID_DispoReseauNiveau_5; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_DispoReseauNiveau_5" FOREIGN KEY ("ID_DispoReseauNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_DispoReseauNiveau_5" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_DispoReseauNiveau_5" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_DispoReseauNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_1 Fk_ID_Niveau_0; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_1"
    ADD CONSTRAINT "Fk_ID_Niveau_0" FOREIGN KEY ("ID_Niveau_0_Fk") REFERENCES geolocalisation."T_Niveau_0"("ID_Niveau_0") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_Niveau_0" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_0" ON geolocalisation."T_Niveau_1" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_1". Définition : FOREIGN KEY ("ID_Niveau_0_Fk") REFERENCES geolocalisation."T_Niveau_0"("ID_Niveau_0") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_2 Fk_ID_Niveau_1; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_Niveau_1" FOREIGN KEY ("ID_Niveau_1_FK") REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_Niveau_1" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_1" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_2". Définition : FOREIGN KEY ("ID_Niveau_1_FK") REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_1 Fk_ID_Niveau_1_Old; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_1"
    ADD CONSTRAINT "Fk_ID_Niveau_1_Old" FOREIGN KEY ("ID_Niveau_1_Old_Fk") REFERENCES geolocalisation."T_Niveau_1_Old"("ID_Niveau_1_Old") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_Niveau_1_Old" ON "T_Niveau_1"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_1_Old" ON geolocalisation."T_Niveau_1" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_1". Définition : FOREIGN KEY ("ID_Niveau_1_Old_Fk") REFERENCES geolocalisation."T_Niveau_1_Old"("ID_Niveau_1_Old") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_3 Fk_ID_Niveau_2; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_Niveau_2" FOREIGN KEY ("ID_Niveau_2_FK") REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_Niveau_2" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_2" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_Niveau_2_FK") REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_4 Fk_ID_Niveau_3; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_Niveau_3" FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_Niveau_3" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_3" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_5 Fk_ID_Niveau_3_N5; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_Niveau_3_N5" FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_Niveau_3_N5" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_3_N5" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_Niveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_5 Fk_ID_Niveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_Niveau_4" FOREIGN KEY ("ID_Niveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_Niveau_4" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Niveau_4" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_Niveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_2 Fk_ID_StatusDeploiFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_StatusDeploiFk" FOREIGN KEY ("ID_StatusDeploiFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_StatusDeploiFk" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatusDeploiFk" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_2". Définition : FOREIGN KEY ("ID_StatusDeploiFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_3 Fk_ID_StatutDeploieFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_StatutDeploieFk" FOREIGN KEY ("ID_StatutDeploieFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_StatutDeploieFk" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutDeploieFk" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_StatutDeploieFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_4 Fk_ID_StatutDeploiementNiveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4" FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutDeploiementNiveau_4" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_5 Fk_ID_StatutDeploiementNiveau_5; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5" FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutDeploiementNiveau_5" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_StatutDeploiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_2 Fk_ID_StatutNiveau_2; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_StatutNiveau_2" FOREIGN KEY ("ID_StatutNiveau_2") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_StatutNiveau_2" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutNiveau_2" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_2". Définition : FOREIGN KEY ("ID_StatutNiveau_2") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_3 Fk_ID_StatutNiveau_3; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_StatutNiveau_3" FOREIGN KEY ("ID_StatutNiveau_3_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_StatutNiveau_3" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutNiveau_3" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_StatutNiveau_3_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_4 Fk_ID_StatutNiveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_StatutNiveau_4" FOREIGN KEY ("ID_StatutNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_StatutNiveau_4" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutNiveau_4" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_StatutNiveau_4") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_5 Fk_ID_StatutNiveau_5; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_StatutNiveau_5" FOREIGN KEY ("ID_StatutNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_StatutNiveau_5" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutNiveau_5" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_StatutNiveau_5") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_2 Fk_ID_TypeNiveau_2; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_TypeNiveau_2" FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_TypeNiveau_2" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_2" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Niveau_3 Fk_ID_TypeNiveau_2; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_TypeNiveau_2" FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_TypeNiveau_2" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_2" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_2_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE';


--
-- Name: T_Niveau_4 Fk_ID_TypeNiveau_4; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_TypeNiveau_4" FOREIGN KEY ("ID_TypeNiveau_4_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_TypeNiveau_4" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeNiveau_4" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeNiveau_4_Fk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE';


--
-- Name: T_Niveau_5 Fk_ID_TypeToitFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_TypeToitFk" FOREIGN KEY ("ID_TypeToitFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_TypeToitFk" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeToitFk" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_TypeToitFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_3 Fk_ID_VoieAccesANTBCZFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_VoieAccesANTBCZFk" FOREIGN KEY ("ID_VoieAccesANTBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_VoieAccesANTBCZFk" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesANTBCZFk" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_VoieAccesANTBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_2 Fk_ID_VoieAccesDPSANTFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_2"
    ADD CONSTRAINT "Fk_ID_VoieAccesDPSANTFk" FOREIGN KEY ("ID_VoieAccesDPSANTFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_VoieAccesDPSANTFk" ON "T_Niveau_2"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesDPSANTFk" ON geolocalisation."T_Niveau_2" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_2". Définition : FOREIGN KEY ("ID_VoieAccesDPSANTFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_3 Fk_ID_VoieAccesDPSBCZFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_3"
    ADD CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk" FOREIGN KEY ("ID_VoieAccesDPSBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk" ON "T_Niveau_3"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesDPSBCZFk" ON geolocalisation."T_Niveau_3" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_3". Définition : FOREIGN KEY ("ID_VoieAccesDPSBCZFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_4 Fk_ID_VoieAccesZsASFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_4"
    ADD CONSTRAINT "Fk_ID_VoieAccesZsASFk" FOREIGN KEY ("ID_VoieAccesZsASFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_VoieAccesZsASFk" ON "T_Niveau_4"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesZsASFk" ON geolocalisation."T_Niveau_4" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_4". Définition : FOREIGN KEY ("ID_VoieAccesZsASFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Niveau_5 Fk_ID_VoieAccesZsSiteFk; Type: FK CONSTRAINT; Schema: geolocalisation; Owner: -
--

ALTER TABLE ONLY geolocalisation."T_Niveau_5"
    ADD CONSTRAINT "Fk_ID_VoieAccesZsSiteFk" FOREIGN KEY ("ID_VoieAccesZsSiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_VoieAccesZsSiteFk" ON "T_Niveau_5"; Type: COMMENT; Schema: geolocalisation; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_VoieAccesZsSiteFk" ON geolocalisation."T_Niveau_5" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "geolocalisation"."T_Niveau_5". Définition : FOREIGN KEY ("ID_VoieAccesZsSiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_CommandeDetail Fk_CmdDetail_Commande; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CommandeDetail"
    ADD CONSTRAINT "Fk_CmdDetail_Commande" FOREIGN KEY ("ID_CmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_CmdDetail_Commande" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_CmdDetail_Commande" ON logistique."T_CommandeDetail" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "logistique"."T_CommandeDetail". Définition : FOREIGN KEY ("ID_CmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: T_Reglements Fk_CodeFacture; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT "Fk_CodeFacture" FOREIGN KEY ("CodeFactureFk") REFERENCES logistique."T_Commande"("CodeFacture");


--
-- Name: CONSTRAINT "Fk_CodeFacture" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_CodeFacture" ON logistique."T_Reglements" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("CodeFactureFk") REFERENCES logistique."T_Commande"("CodeFacture")';


--
-- Name: T_CommandeDetail Fk_ID_Article; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CommandeDetail"
    ADD CONSTRAINT "Fk_ID_Article" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_Article" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Article" ON logistique."T_CommandeDetail" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE';


--
-- Name: T_Article Fk_ID_CategorieArticle; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "Fk_ID_CategorieArticle" FOREIGN KEY ("ID_CategorieArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_CategorieArticle" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_CategorieArticle" ON logistique."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_CategorieArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Commande Fk_ID_ConditionPaiement; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_ConditionPaiement" FOREIGN KEY ("ID_ConditionPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_ConditionPaiement" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_ConditionPaiement" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ConditionPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Commande Fk_ID_ModePaiement; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_ModePaiement" FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_ModePaiement" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_ModePaiement" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Commande Fk_ID_StatutCmd; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_StatutCmd" FOREIGN KEY ("ID_StatutCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_StatutCmd" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutCmd" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_StatutCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Article Fk_ID_TypeArticle; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "Fk_ID_TypeArticle" FOREIGN KEY ("ID_TypeArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_TypeArticle" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeArticle" ON logistique."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Commande Fk_ID_TypeCmd; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_TypeCmd" FOREIGN KEY ("ID_TypeCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_TypeCmd" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeCmd" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Mouvement Fk_ID_TypeMvt; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT "Fk_ID_TypeMvt" FOREIGN KEY ("ID_TypeMvtFk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_TypeMvt" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeMvt" ON logistique."T_Mouvement" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeMvtFk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Article Fk_ID_Unite; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "Fk_ID_Unite" FOREIGN KEY ("ID_UniteFk") REFERENCES referentiel."T_Generique"("ID_Generique");


--
-- Name: CONSTRAINT "Fk_ID_Unite" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Unite" ON logistique."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UniteFk") REFERENCES referentiel."T_Generique"("ID_Generique")';


--
-- Name: T_Article Fk_ID_User; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "Fk_ID_User" FOREIGN KEY ("ID_UserFK") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_User" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_User" ON logistique."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UserFK") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE';


--
-- Name: T_Commande Fk_ID_User; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_User" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_User" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_User" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE';


--
-- Name: T_Mouvement Fk_Mvt_Article; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT "Fk_Mvt_Article" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_Mvt_Article" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Mvt_Article" ON logistique."T_Mouvement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "logistique"."T_Mouvement". Définition : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE.';


--
-- Name: T_Mouvement Fk_Mvt_Cmd; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT "Fk_Mvt_Cmd" FOREIGN KEY ("ID_cmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Mvt_Cmd" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Mvt_Cmd" ON logistique."T_Mouvement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "logistique"."T_Mouvement". Définition : FOREIGN KEY ("ID_cmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Reglements Fk_Reg_Mode; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT "Fk_Reg_Mode" FOREIGN KEY ("ID_ModeReglementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_Reg_Mode" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Reg_Mode" ON logistique."T_Reglements" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "logistique"."T_Reglements". Définition : FOREIGN KEY ("ID_ModeReglementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Caisse Fk_IdDevise; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "Fk_IdDevise" FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdDevise" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdDevise" ON operations."T_Caisse" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Caisse". Définition : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Paiement Fk_IdDevise; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdDevise" FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdDevise" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdDevise" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Caisse Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Caisse" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Caisse". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Paiement Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: T_Paiement_Archive Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement_Archive"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Paiement_Archive" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement_Archive". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Paiement Fk_IdPayeurFk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdPayeurFk" FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdPayeurFk" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdPayeurFk" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Paiement Fk_IdTypePaiement; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdTypePaiement" FOREIGN KEY ("IdTypePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdTypePaiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdTypePaiement" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdTypePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Paiement Fk_IdUserFk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdUserFk" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdUserFk" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdUserFk" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';


--
-- Name: T_Professionnel_Entite Fk_ProfEnt_Entite; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: CONSTRAINT "Fk_ProfEnt_Entite" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_Entite" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: T_Professionnel_Entite Fk_ProfEnt_Prof; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_Prof" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_ProfEnt_Prof" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_Prof" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: T_Professionnel_Entite Fk_ProfEnt_TypeLien; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_TypeLien" FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: CONSTRAINT "Fk_ProfEnt_TypeLien" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_TypeLien" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: T_Professionnel Fk_Prof_Specialite; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_Specialite" FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: CONSTRAINT "Fk_Prof_Specialite" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_Specialite" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: T_Professionnel Fk_Prof_TypeProfessionnel; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_TypeProfessionnel" FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: CONSTRAINT "Fk_Prof_TypeProfessionnel" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_TypeProfessionnel" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: T_Professionnel Fk_Prof_User; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_User" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: CONSTRAINT "Fk_Prof_User" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_User" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';


--
-- Name: T_Generique Fk_ID_CategorieGenerique; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_Generique"
    ADD CONSTRAINT "Fk_ID_CategorieGenerique" FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_CategorieGenerique" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_CategorieGenerique" ON referentiel."T_Generique" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "referentiel"."T_Generique". Définition : FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE.';


--
-- Name: T_Admin_UI_Setting Fk_Admin_UI_Setting_User; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Admin_UI_Setting"
    ADD CONSTRAINT "Fk_Admin_UI_Setting_User" FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Admin_UI_Setting_User" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Admin_UI_Setting_User" ON systeme."T_Admin_UI_Setting" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Admin_UI_Setting". Définition : FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Entite_Localisation Fk_EL_Entite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Fk_EL_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_EL_Entite" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_EL_Entite" ON systeme."T_Entite_Localisation" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite_Localisation". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: T_Entite_Localisation Fk_EL_N3; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Fk_EL_N3" FOREIGN KEY ("IdNiveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3");


--
-- Name: CONSTRAINT "Fk_EL_N3" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_EL_N3" ON systeme."T_Entite_Localisation" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite_Localisation". Définition : FOREIGN KEY ("IdNiveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3").';


--
-- Name: T_Entite_Localisation Fk_EL_N4; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Fk_EL_N4" FOREIGN KEY ("IdNiveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4");


--
-- Name: CONSTRAINT "Fk_EL_N4" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_EL_N4" ON systeme."T_Entite_Localisation" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite_Localisation". Définition : FOREIGN KEY ("IdNiveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4").';


--
-- Name: T_Entite_Localisation Fk_EL_N5; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Fk_EL_N5" FOREIGN KEY ("IdNiveau_5_Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5");


--
-- Name: CONSTRAINT "Fk_EL_N5" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_EL_N5" ON systeme."T_Entite_Localisation" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite_Localisation". Définition : FOREIGN KEY ("IdNiveau_5_Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5").';


--
-- Name: T_Licence Fk_Entite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Licence"
    ADD CONSTRAINT "Fk_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_Entite" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Entite" ON systeme."T_Licence" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Licence". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE.';


--
-- Name: T_Fk_Correspondance Fk_FkCorrespondance_Category; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "Fk_FkCorrespondance_Category" FOREIGN KEY ("TargetCategoryIdFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_FkCorrespondance_Category" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_FkCorrespondance_Category" ON systeme."T_Fk_Correspondance" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Fk_Correspondance". Définition : FOREIGN KEY ("TargetCategoryIdFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Fk_Correspondance Fk_FkCorrespondance_User; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "Fk_FkCorrespondance_User" FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_FkCorrespondance_User" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_FkCorrespondance_User" ON systeme."T_Fk_Correspondance" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Fk_Correspondance". Définition : FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Audit_Log Fk_IdEntite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Audit_Log"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Audit_Log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON systeme."T_Audit_Log" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Audit_Log". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Login Fk_IdEntite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Login"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON systeme."T_Login" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Login". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Utilisateurs Fk_IdEntite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON systeme."T_Utilisateurs" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Utilisateurs". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Login Fk_IdTypeLogin; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Login"
    ADD CONSTRAINT "Fk_IdTypeLogin" FOREIGN KEY ("IdTypeLoginFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdTypeLogin" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdTypeLogin" ON systeme."T_Login" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Login". Définition : FOREIGN KEY ("IdTypeLoginFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Login Fk_IdUserFk; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Login"
    ADD CONSTRAINT "Fk_IdUserFk" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdUserFk" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdUserFk" ON systeme."T_Login" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Login". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';


--
-- Name: T_Utilisateurs Fk_RoleFk; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT "Fk_RoleFk" FOREIGN KEY ("IdRoleFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_RoleFk" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_RoleFk" ON systeme."T_Utilisateurs" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Utilisateurs". Définition : FOREIGN KEY ("IdRoleFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Licence Fk_StatutLicence; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Licence"
    ADD CONSTRAINT "Fk_StatutLicence" FOREIGN KEY ("IdStatutLicenceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_StatutLicence" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_StatutLicence" ON systeme."T_Licence" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Licence". Définition : FOREIGN KEY ("IdStatutLicenceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Entite Fk_TypeEntite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite"
    ADD CONSTRAINT "Fk_TypeEntite" FOREIGN KEY ("IdTypeEntiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_TypeEntite" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_TypeEntite" ON systeme."T_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite". Définition : FOREIGN KEY ("IdTypeEntiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- PostgreSQL database dump complete
--

\unrestrict e4nuZPOf6YNStl1uWqfrqr3hpJkqpGLB7dlGCtSNVWHRrAitNe7niriwM9dkPjS
