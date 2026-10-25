-- Extrait canonique du catalogue installé le 24/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "logistique";
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
        CASE WHEN TG_OP = 'INSERT' OR v_delta > 0 THEN COALESCE(NEW."PUArticle", 0) ELSE COALESCE(NEW."PVArticle", 0) END
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

COMMENT ON FUNCTION logistique.tr_crud_article_after() IS 'Après INSERT/UPDATE d’article, historise uniquement le stock initial non nul ou le delta direct : les entrées utilisent PUArticle (prix d’achat), les sorties conservent PVArticle. Aucun mouvement historique réécrit. Le drapeau skip_article_report_mvt évite tout double report depuis les lignes de bon, dont PUMvt reste leur PUCmdDetail explicite.';


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

COMMENT ON TRIGGER tr_crud_article_after ON logistique."T_Article" IS 'Historise le stock initial et les deltas directs : entrées au prix d’achat PUArticle, sorties au prix de vente PVArticle ; aucun second mouvement pour les lignes de bon.';


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
