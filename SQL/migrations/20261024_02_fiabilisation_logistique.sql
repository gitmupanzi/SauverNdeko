-- SauverNdeko 20261024_02 : cohérence et coût des vues/triggers logistiques.
-- Préconditions : structure de la migration d’alignement logistique ; PostgreSQL >= 15.
-- Ne réécrit aucune donnée existante. Les futures écritures utilisent les nouveaux contrôles.
-- Le calcul HT=TTC existant et les quantités entières sont conservés.
BEGIN;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='120s';
LOCK TABLE logistique."T_Article", logistique."T_Commande", logistique."T_CommandeDetail", logistique."T_Mouvement", logistique."T_Reglements" IN SHARE ROW EXCLUSIVE MODE;
CREATE OR REPLACE FUNCTION logistique.fn_commande_cloturee(p_statut text)
RETURNS boolean LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $function$
 SELECT translate(lower(btrim(COALESCE(p_statut, ''))),
   'àâäéèêëîïôöùûüç', 'aaaeeeeiioouuuc') = 'cloturee';
$function$;
CREATE OR REPLACE FUNCTION logistique.tr_lock_commande_cloturee()
RETURNS trigger LANGUAGE plpgsql
AS $function$
BEGIN
 IF logistique.fn_commande_cloturee(OLD."StatusFacture") THEN
  RAISE EXCEPTION 'Commande % clôturée : modification ou suppression interdite.', OLD."ID_Commande"
   USING ERRCODE = '23514';
 END IF;
 IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$function$;
CREATE OR REPLACE FUNCTION logistique.tr_guard_commandedetail()
RETURNS trigger LANGUAGE plpgsql
AS $function$
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
$function$;
CREATE OR REPLACE PROCEDURE logistique.ps_update_totaux_commande(IN p_id_commande integer)
LANGUAGE plpgsql
AS $procedure$
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
$procedure$;
CREATE OR REPLACE FUNCTION logistique.tr_totaux_commande()
RETURNS trigger LANGUAGE plpgsql
AS $function$
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
$function$;
CREATE OR REPLACE FUNCTION logistique.fn_audit_stock(p_id_article integer DEFAULT NULL::integer, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone)
 RETURNS TABLE("ID_Article" integer, "CodeArticleInterne" character varying, "NomArticle" character varying, "StockArticle" numeric, "StockMouvements" numeric, "Ecart" numeric, "N_Mouvements" integer, "QteEntree" numeric, "QteSortie" numeric)
 LANGUAGE sql
 STABLE
 PARALLEL SAFE
AS $function$
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
$function$;
CREATE OR REPLACE VIEW logistique."V_AlertStock" AS
 SELECT "ID_Article",
    "CodeArticleInterne",
    "NomArticle",
    "AbrUnite",
    "QteArticle",
    "QteMinArticle",
    "QteACommander",
    (COALESCE("QteArticle", 0::numeric) - COALESCE("QteMinArticle", 0)::numeric)::numeric(14,3) AS "Marge",
    "EtatStock",
    "EstRupture",
    "EstAlerteStock",
    "PrioriteStock",
    "EtatPeremption",
    "JoursAvantPeremption",
    "EstPerime",
    "EstAlertePeremption"
   FROM logistique."V_Article" a
  WHERE ("EstRupture" = true OR "EstAlerteStock" = true);
CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS
 WITH conso AS (
         SELECT v."ID_ArticleFk",
            sum(
                CASE
                    WHEN v."SigneStock" = '-1'::integer THEN COALESCE(v."QteMvt", 0)
                    ELSE 0
                END)::numeric AS conso_6m
           FROM logistique."V_MouvementStock" v
          WHERE v."DateMvt" >= (CURRENT_DATE - '6 mons'::interval) AND v."DateMvt" < (CURRENT_DATE + '1 day'::interval)
          GROUP BY v."ID_ArticleFk"
        )
 SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    a."AbrUnite",
    a."QteArticle" AS "StockActuel",
    COALESCE(conso.conso_6m, 0::numeric) AS "Conso6Mois",
    round(COALESCE(conso.conso_6m, 0::numeric) / 6.0, 2) AS "ConsoMoyMensuelle",
        CASE
            WHEN COALESCE(conso.conso_6m, 0::numeric) = 0::numeric THEN NULL::numeric
            ELSE round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1)
        END AS "CouvertureMois",
        CASE
            WHEN COALESCE(conso.conso_6m, 0::numeric) = 0::numeric THEN 'Aucune consommation récente'::text
            WHEN round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1) < 1::numeric THEN 'Critique'::text
            WHEN round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1) < 3::numeric THEN 'Faible'::text
            ELSE 'Correcte'::text
        END AS "EtatCouverture"
   FROM logistique."V_Article" a
     LEFT JOIN conso ON conso."ID_ArticleFk" = a."ID_Article";
DROP TRIGGER IF EXISTS tr_totaux_commande ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_totaux_commande_insert ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_totaux_commande_update ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_totaux_commande_delete ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_00_guard_commandedetail ON logistique."T_CommandeDetail";
CREATE TRIGGER tr_00_guard_commandedetail BEFORE INSERT OR UPDATE OR DELETE
 ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_guard_commandedetail();
CREATE TRIGGER tr_totaux_commande_insert AFTER INSERT ON logistique."T_CommandeDetail"
 REFERENCING NEW TABLE AS lignes_nouvelles FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();
CREATE TRIGGER tr_totaux_commande_update AFTER UPDATE ON logistique."T_CommandeDetail"
 REFERENCING OLD TABLE AS lignes_anciennes NEW TABLE AS lignes_nouvelles
 FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();
CREATE TRIGGER tr_totaux_commande_delete AFTER DELETE ON logistique."T_CommandeDetail"
 REFERENCING OLD TABLE AS lignes_anciennes FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();
COMMENT ON FUNCTION logistique.fn_commande_cloturee(text) IS 'Prédicat commun de clôture : normalise espaces, casse et accents français du statut ; vrai pour Clôturée/cloturee. Sans lecture de données ni effet de bord.';
COMMENT ON FUNCTION logistique.tr_guard_commandedetail() IS 'Avant chaque mutation de ligne, verrouille les commandes concernées par identifiant croissant et refuse les commandes clôturées. Sérialise les saisies pour éviter les totaux perdus ; accepte la disparition du parent lors d’un DELETE en cascade déjà autorisé.';
COMMENT ON FUNCTION logistique.tr_lock_commande_cloturee() IS 'Avant UPDATE/DELETE de commande, refuse une commande clôturée selon le prédicat commun normalisé fn_commande_cloturee ; contrôle l’état OLD.';
COMMENT ON PROCEDURE logistique.ps_update_totaux_commande(integer) IS 'Verrouille une commande puis recalcule la somme quantité × prix des lignes. Écrit cette somme dans HT et TTC uniquement si nécessaire ; aucun calcul de taxe distinct. Parent absent lors d’une cascade : aucune écriture.';
COMMENT ON FUNCTION logistique.tr_totaux_commande() IS 'Fonction des trois triggers AFTER STATEMENT de lignes : utilise les tables de transition pour recalculer une seule fois chaque commande affectée, y compris ancien/nouveau parent en UPDATE. Aucune boucle de recalcul par ligne.';
COMMENT ON FUNCTION logistique.fn_audit_stock(integer, timestamp without time zone) IS 'Lecture SQL STABLE de l’audit au grain article, intégrable par le planificateur pour pousser les filtres d’article. Compare le stock courant aux mouvements signés ; p_date_max borne les mouvements sans reconstituer un stock historique.';
COMMENT ON VIEW logistique."V_AlertStock" IS 'Articles en rupture ou au seuil minimal depuis V_Article, au grain article. Les ruptures sont incluses même sans seuil renseigné ; les autres alertes exigent le seuil défini dans V_Article.';
COMMENT ON VIEW logistique."V_CouvertureStock" IS 'Couverture au grain article : sorties depuis CURRENT_DATE moins six mois et avant le lendemain de CURRENT_DATE. Moyenne divisée par six puis stock/moyenne ; les jours futurs sont exclus, NULL sans consommation.';
COMMENT ON COLUMN logistique."V_CouvertureStock"."Conso6Mois" IS 'Quantités de sorties du début glissant à six mois inclus au lendemain du jour courant exclu ; les mouvements datés d’un jour futur ne contribuent pas. Expression : COALESCE(conso.conso_6m, 0::numeric).';
COMMENT ON TRIGGER tr_00_guard_commandedetail ON logistique."T_CommandeDetail" IS 'BEFORE ROW : verrouille les parents et contrôle leur clôture avant la mutation de ligne et ses effets stock.';
COMMENT ON TRIGGER tr_totaux_commande_insert ON logistique."T_CommandeDetail" IS 'AFTER INSERT STATEMENT : recalcule les commandes distinctes de lignes_nouvelles, après les effets stock de chaque ligne.';
COMMENT ON TRIGGER tr_totaux_commande_update ON logistique."T_CommandeDetail" IS 'AFTER UPDATE STATEMENT : recalcule les commandes distinctes des anciennes et nouvelles lignes ; une commande est recalculée au plus une fois par instruction.';
COMMENT ON TRIGGER tr_totaux_commande_delete ON logistique."T_CommandeDetail" IS 'AFTER DELETE STATEMENT : recalcule les commandes distinctes des lignes supprimées ; tolère le parent déjà supprimé en cascade.';
COMMIT;
