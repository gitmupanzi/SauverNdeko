-- Prix des nouvelles entrées directes/initiales : PUArticle, sans réécriture historique.
-- Les réceptions par bon conservent exclusivement le PUCmdDetail saisi sur leur ligne.
-- Précondition : définition réelle du trigger inspectée avant livraison ; sauvegarde vérifiée requise.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
SET LOCAL search_path = pg_catalog, public;
DO $preconditions$
BEGIN
 IF current_database()<>'SauverNdeko' AND current_setting('sauverndeko.fixture_reception',true) IS DISTINCT FROM 'on' THEN
  RAISE EXCEPTION 'Migration réservée à SauverNdeko ou à une recette isolée explicitement identifiée.';
 END IF;
 IF md5(pg_get_functiondef('logistique.tr_crud_article_after()'::regprocedure))<>'873e3e1b7fdb1502e28a798c4599060d' THEN
  RAISE EXCEPTION 'Définition du trigger Article différente du prérequis vérifié ; examiner avant application.';
 END IF;
END;
$preconditions$;
-- Fenêtre bornée : les lignes métier ne peuvent changer pendant la preuve avant/après.
LOCK TABLE logistique."T_Article",logistique."T_Commande",logistique."T_CommandeDetail",logistique."T_Mouvement",
 logistique."T_Reglements",logistique."T_LotArticle",logistique."T_MouvementLot" IN ACCESS EXCLUSIVE MODE;
CREATE TEMP TABLE migration_prix_entrees_before (objet text PRIMARY KEY,lignes bigint,empreinte text) ON COMMIT DROP;
DO $empreintes$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['T_Article','T_Commande','T_CommandeDetail','T_Mouvement','T_Reglements','T_LotArticle','T_MouvementLot'] LOOP
  EXECUTE format('INSERT INTO migration_prix_entrees_before SELECT %L,count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),%L ORDER BY to_jsonb(x)::text),%L)) FROM logistique.%I x',t,'','',t);
 END LOOP;
END;
$empreintes$;
CREATE OR REPLACE FUNCTION logistique.tr_crud_article_after()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$;

COMMENT ON FUNCTION logistique.tr_crud_article_after() IS 'Après INSERT/UPDATE d’article, historise uniquement le stock initial non nul ou le delta direct : les entrées utilisent PUArticle (prix d’achat), les sorties conservent PVArticle. Aucun mouvement historique réécrit. Le drapeau skip_article_report_mvt évite tout double report depuis les lignes de bon, dont PUMvt reste leur PUCmdDetail explicite.';
COMMENT ON TRIGGER tr_crud_article_after ON logistique."T_Article" IS 'Historise le stock initial et les deltas directs : entrées au prix d’achat PUArticle, sorties au prix de vente PVArticle ; aucun second mouvement pour les lignes de bon.';
DO $verification$
DECLARE t text; avant record; lignes_apres bigint; empreinte_apres text;
BEGIN
 IF md5(pg_get_functiondef('logistique.tr_crud_article_after()'::regprocedure))<>'c38a800f806b0a1e367b187a673f638e' THEN
  RAISE EXCEPTION 'La définition du trigger Article ne correspond pas à la version validée.';
 END IF;
 FOREACH t IN ARRAY ARRAY['T_Article','T_Commande','T_CommandeDetail','T_Mouvement','T_Reglements','T_LotArticle','T_MouvementLot'] LOOP
  SELECT * INTO STRICT avant FROM migration_prix_entrees_before WHERE objet=t;
  EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),%L ORDER BY to_jsonb(x)::text),%L)) FROM logistique.%I x','','',t) INTO lignes_apres,empreinte_apres;
  IF avant.lignes IS DISTINCT FROM lignes_apres OR avant.empreinte IS DISTINCT FROM empreinte_apres THEN
   RAISE EXCEPTION 'Les données historiques de % ont changé : transaction annulée.',t;
  END IF;
 END LOOP;
END;
$verification$;
COMMIT;
