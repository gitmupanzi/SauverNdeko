-- Retour aux définitions et commentaires relevés avant 20261024_02.
BEGIN;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='120s';
DROP TRIGGER IF EXISTS tr_00_guard_commandedetail ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_totaux_commande_insert ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_totaux_commande_update ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_totaux_commande_delete ON logistique."T_CommandeDetail";
CREATE OR REPLACE FUNCTION logistique.tr_lock_commande_cloturee()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ BEGIN IF OLD."StatusFacture" = 'Clôturée' THEN RAISE EXCEPTION 'Commande % cloturee/facturee : modification ou suppression interdite.',
    OLD."ID_Commande";
END IF;
IF TG_OP = 'DELETE' THEN RETURN OLD;
END IF;
RETURN NEW;
END;
$function$;
CREATE OR REPLACE PROCEDURE logistique.ps_update_totaux_commande(IN p_id_commande integer)
 LANGUAGE plpgsql
AS $procedure$
DECLARE v_montant_ht numeric(12, 2);
BEGIN
SELECT COALESCE(
        SUM(
            COALESCE(cd."QteCmdDetail", 0) * COALESCE(cd."PUCmdDetail", 0)
        ),
        0
    ) INTO v_montant_ht
FROM logistique."T_CommandeDetail" cd
WHERE cd."ID_CmdFk" = p_id_commande;
UPDATE logistique."T_Commande"
SET "MontantHT" = v_montant_ht,
    "MontantTTC" = v_montant_ht
WHERE "ID_Commande" = p_id_commande;
END;
$procedure$;
CREATE OR REPLACE FUNCTION logistique.tr_totaux_commande()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE v_id_cmd integer;
BEGIN IF TG_OP = 'INSERT' THEN v_id_cmd := NEW."ID_CmdFk";
ELSIF TG_OP = 'UPDATE' THEN IF OLD."ID_CmdFk" IS DISTINCT
FROM NEW."ID_CmdFk" THEN CALL logistique.ps_update_totaux_commande(OLD."ID_CmdFk");
END IF;
v_id_cmd := NEW."ID_CmdFk";
ELSIF TG_OP = 'DELETE' THEN v_id_cmd := OLD."ID_CmdFk";
ELSE RETURN NEW;
END IF;
CALL logistique.ps_update_totaux_commande(v_id_cmd);
IF TG_OP = 'DELETE' THEN RETURN OLD;
END IF;
RETURN NEW;
END;
$function$;
CREATE OR REPLACE FUNCTION logistique.fn_audit_stock(p_id_article integer DEFAULT NULL::integer, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone)
 RETURNS TABLE("ID_Article" integer, "CodeArticleInterne" character varying, "NomArticle" character varying, "StockArticle" numeric, "StockMouvements" numeric, "Ecart" numeric, "N_Mouvements" integer, "QteEntree" numeric, "QteSortie" numeric)
 LANGUAGE plpgsql
AS $function$ BEGIN RETURN QUERY
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
END;
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
  WHERE "QteMinArticle" IS NOT NULL AND ("EstRupture" = true OR "EstAlerteStock" = true);
CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS
 WITH conso AS (
         SELECT v."ID_ArticleFk",
            sum(
                CASE
                    WHEN v."SigneStock" = '-1'::integer THEN COALESCE(v."QteMvt", 0)
                    ELSE 0
                END)::numeric AS conso_6m
           FROM logistique."V_MouvementStock" v
          WHERE v."DateMvt" >= (CURRENT_DATE - '6 mons'::interval)
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
CREATE TRIGGER tr_totaux_commande AFTER INSERT OR DELETE OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_totaux_commande();
DROP FUNCTION logistique.tr_guard_commandedetail();
DROP FUNCTION logistique.fn_commande_cloturee(text);
COMMENT ON FUNCTION logistique.tr_lock_commande_cloturee() IS 'Avant UPDATE/DELETE de commande, refuse l’opération si OLD.StatusFacture vaut exactement Clôturée. La comparaison actuelle ne normalise pas la casse ou les variantes de libellé.';
COMMENT ON PROCEDURE logistique.ps_update_totaux_commande(integer) IS 'Recalcule la somme quantité × prix des lignes d’une commande et écrit cette même somme dans MontantHT et MontantTTC. Aucun calcul distinct de taxe ou remise n’est effectué par cette procédure.';
COMMENT ON FUNCTION logistique.tr_totaux_commande() IS 'Après mutation de ligne, recalcule les totaux de la commande concernée via ps_update_totaux_commande ; recalcule aussi l’ancienne commande si le rattachement change.';
COMMENT ON FUNCTION logistique.fn_audit_stock(integer, timestamp without time zone) IS 'Lecture d’audit au grain article : compare QteArticle courant à la somme des mouvements signés, avec filtre optionnel article et DateMvt <= p_date_max. La borne date ne reconstitue pas un ancien QteArticle ; p_date_max NULL retient tous les mouvements.';
COMMENT ON VIEW logistique."V_AlertStock" IS 'Articles ayant un seuil renseigné et un état de rupture ou de stock faible, depuis V_Article. Grain : article ; une rupture sans seuil renseigné n’entre pas dans cette vue.';
COMMENT ON VIEW logistique."V_CouvertureStock" IS 'Couverture au grain article : sorties datées depuis CURRENT_DATE moins six mois, moyenne obtenue en divisant par six, puis stock actuel/moyenne. Couverture NULL sans consommation ; aucune borne haute de date n’est appliquée par la définition actuelle.';
COMMENT ON COLUMN logistique."V_CouvertureStock"."Conso6Mois" IS 'Quantités sorties depuis CURRENT_DATE moins six mois ; la définition actuelle ne borne pas les dates futures. Expression projetée : COALESCE(conso.conso_6m, 0::numeric) AS "Conso6Mois".';
COMMENT ON TRIGGER tr_totaux_commande ON logistique."T_CommandeDetail" IS 'AFTER INSERT OR DELETE OR UPDATE sur "logistique"."T_CommandeDetail", pour chaque ligne. Appelle "logistique"."tr_totaux_commande" : Après mutation de ligne, recalcule les totaux de la commande concernée via ps_update_totaux_commande ; recalcule aussi l’ancienne commande si le rattachement change.';
COMMIT;
