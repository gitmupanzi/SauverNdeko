-- Retour arrière logique de 20261024_04.
-- Les validations de FK sont conservées. Aucun journal ou historique n’est effacé.
-- Refuse de supprimer le nouveau socle analytics s’il contient des événements.
-- Revenir aussi au backend compatible avec les anciennes vues avant application.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(hashtextextended('sauverndeko:20261024_04',0));
DO $body$ BEGIN IF EXISTS(SELECT 1 FROM analytics."T_Recherche") THEN
 RAISE EXCEPTION 'Retour arrière refusé : analytics contient des événements à préserver.'; END IF; END;$body$;
DROP TRIGGER IF EXISTS tr_guard_sens_stock ON referentiel."T_Generique";
DROP TRIGGER IF EXISTS tr_00_lock_discussion_message ON communication."T_Chat";
DROP TRIGGER IF EXISTS tr_sync_dernier_message ON communication."T_Chat";
DROP VIEW IF EXISTS "analytics"."V_Recherche";
DROP VIEW IF EXISTS "professionnel"."V_Professionnel_Public";
DROP VIEW IF EXISTS "professionnel"."V_Professionnel_Detail";
DROP VIEW IF EXISTS "professionnel"."V_Professionnel_Global";
DROP VIEW IF EXISTS "professionnel"."V_Professionnel_Par_Entite";
DROP VIEW IF EXISTS "systeme"."V_Entite_Public";
DROP VIEW IF EXISTS "communication"."V_Chat";
DROP VIEW IF EXISTS "communication"."V_Communication";
DROP VIEW IF EXISTS "communication"."V_Communication_non_lues";
DROP TABLE analytics."T_Recherche";
CREATE OR REPLACE VIEW "systeme"."V_Audit_log" AS
 SELECT a."IdLog",
    a."TableName",
    a."Operation",
    a."ChangedAt",
    e."NomEntite",
    a."OldData",
    a."NewData"
   FROM systeme."T_Audit_Log" a
     LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = a."IdEntiteFk";
COMMENT ON VIEW "systeme"."V_Audit_log" IS 'Journal d’audit enrichi du nom d’entité, au grain événement ; conserve les états JSON avant et après sans filtrage d’autorisation intégré.';
COMMENT ON COLUMN "systeme"."V_Audit_log"."IdLog" IS 'Identifiant de l’événement d’audit. Expression projetée : a."IdLog".';
COMMENT ON COLUMN "systeme"."V_Audit_log"."TableName" IS 'Nom de la table à l’origine de l’événement d’audit. Expression projetée : a."TableName".';
COMMENT ON COLUMN "systeme"."V_Audit_log"."Operation" IS 'Nom de l’opération auditée ; le trigger produit INSERT, UPDATE ou DELETE. Expression projetée : a."Operation".';
COMMENT ON COLUMN "systeme"."V_Audit_log"."ChangedAt" IS 'Horodatage de l’événement d’audit. Expression projetée : a."ChangedAt".';
COMMENT ON COLUMN "systeme"."V_Audit_log"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';
COMMENT ON COLUMN "systeme"."V_Audit_log"."OldData" IS 'Valeurs avant l’opération auditable, sérialisées en JSON ; NULL lors d’une insertion par le trigger d’audit. Expression projetée : a."OldData".';
COMMENT ON COLUMN "systeme"."V_Audit_log"."NewData" IS 'Valeurs après l’opération auditable, sérialisées en JSON ; NULL lors d’une suppression par le trigger d’audit. Expression projetée : a."NewData".';
CREATE OR REPLACE VIEW "systeme"."V_Licence_active" AS
 SELECT l."IdLicence",
    l."IdEntiteFk",
    e."NomEntite",
    l."DateDebut",
    l."DateFin",
    l."ValideLicence",
    l."ExpireeLicence",
        CASE
            WHEN l."DateFin" < CURRENT_DATE THEN 'Expirée'::text
            WHEN l."ExpireeLicence" = true THEN 'Expirée'::text
            ELSE 'Active'::text
        END AS statut_licence
   FROM systeme."T_Licence" l
     LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = l."IdEntiteFk";
COMMENT ON VIEW "systeme"."V_Licence_active" IS 'Projection de toutes les licences et de leur entité, avec statut calculé depuis DateFin/CURRENT_DATE et ExpireeLicence. Malgré son nom, la vue ne filtre ni les licences expirées ni ValideLicence.';
COMMENT ON COLUMN "systeme"."V_Licence_active"."IdLicence" IS 'Identifiant de la licence. Expression projetée : l."IdLicence".';
COMMENT ON COLUMN "systeme"."V_Licence_active"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Expression projetée : l."IdEntiteFk".';
COMMENT ON COLUMN "systeme"."V_Licence_active"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';
COMMENT ON COLUMN "systeme"."V_Licence_active"."DateDebut" IS 'Début de la période enregistrée. Expression projetée : l."DateDebut".';
COMMENT ON COLUMN "systeme"."V_Licence_active"."DateFin" IS 'Fin de la période enregistrée. Expression projetée : l."DateFin".';
COMMENT ON COLUMN "systeme"."V_Licence_active"."ValideLicence" IS 'Indique si la licence est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : l."ValideLicence".';
COMMENT ON COLUMN "systeme"."V_Licence_active"."ExpireeLicence" IS 'Indicateur d’expiration calculé à l’écriture de la licence à partir de DateFin ; ne se met pas à jour seul avec le passage du temps. Expression projetée : l."ExpireeLicence".';
COMMENT ON COLUMN "systeme"."V_Licence_active"."statut_licence" IS 'Expirée si DateFin < CURRENT_DATE ou ExpireeLicence vrai, sinon Active ; ne contrôle pas ValideLicence. Expression projetée : CASE WHEN l."DateFin" < CURRENT_DATE THEN ''Expirée''::text WHEN l."ExpireeLicence" = true THEN ''Expirée''::text ELSE ''Active''::text END AS statut_licence.';
CREATE OR REPLACE VIEW "geolocalisation"."V_Stats_N3_Structures" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_TypeNiveau_4_Fk",
    COALESCE(g_type4."AbrGenerique", ' '::character varying) AS "Type_Niveau_4",
    n5."ID_TypeNiveau_5_Fk",
    COALESCE(g_type5."AbrGenerique", ' '::character varying) AS "Type_Niveau_5",
    count(DISTINCT n4."ID_Niveau_4") AS "Nb_Aires_Sante",
    count(DISTINCT n5."ID_Niveau_5") AS "Nb_Structures_Sante"
   FROM geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
     LEFT JOIN geolocalisation."T_Niveau_5" n5 ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
     LEFT JOIN referentiel."T_Generique" g_type4 ON n4."ID_TypeNiveau_4_Fk" = g_type4."ID_Generique"
     LEFT JOIN referentiel."T_Generique" g_type5 ON n5."ID_TypeNiveau_5_Fk" = g_type5."ID_Generique"
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3", n4."ID_TypeNiveau_4_Fk", g_type4."AbrGenerique", n5."ID_TypeNiveau_5_Fk", g_type5."AbrGenerique";
COMMENT ON VIEW "geolocalisation"."V_Stats_N3_Structures" IS 'Vue d''indicateurs par Zone de Sante et par type : Aires de Sante et structures de sante.';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."ID_TypeNiveau_4_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n4."ID_TypeNiveau_4_Fk".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."Type_Niveau_4" IS 'Abréviation du type d’unité de niveau 4 dans le référentiel. Expression projetée : COALESCE(g_type4."AbrGenerique", '' ''::character varying) AS "Type_Niveau_4".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n5."ID_TypeNiveau_5_Fk".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."Type_Niveau_5" IS 'Abréviation du type d’unité de niveau 5 dans le référentiel. Expression projetée : COALESCE(g_type5."AbrGenerique", '' ''::character varying) AS "Type_Niveau_5".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."Nb_Aires_Sante" IS 'Nombre d’aires de santé distinctes dans le groupe zone/types de structure. Expression projetée : count(DISTINCT n4."ID_Niveau_4") AS "Nb_Aires_Sante".';
COMMENT ON COLUMN "geolocalisation"."V_Stats_N3_Structures"."Nb_Structures_Sante" IS 'Nombre de sites de santé distincts dans le groupe zone/types de structure. Expression projetée : count(DISTINCT n5."ID_Niveau_5") AS "Nb_Structures_Sante".';
CREATE OR REPLACE VIEW "geolocalisation"."V_Pop_N3_Couverte_Sites" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n5."ID_TypeNiveau_5_Fk",
    COALESCE(g_type5."AbrGenerique", ' '::character varying) AS "Type_Niveau_5",
    sum(COALESCE(n5."PopulationNiveau_5", 0::numeric)) AS "Pop_Cum_Sites"
   FROM geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n3."ID_Niveau_2_FK" = n2."ID_Niveau_2"
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n2."ID_Niveau_1_FK" = n1."ID_Niveau_1"
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0"
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n3."ID_Niveau_3" = n4."ID_Niveau_3_Fk"
     LEFT JOIN geolocalisation."T_Niveau_5" n5 ON n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk"
     LEFT JOIN referentiel."T_Generique" g_type5 ON n5."ID_TypeNiveau_5_Fk" = g_type5."ID_Generique"
  GROUP BY n0."ID_Niveau_0", n0."NomNiveau_0", n1."ID_Niveau_1", n1."NomNiveau_1", n2."ID_Niveau_2", n2."NomNiveau_2", n3."ID_Niveau_3", n3."NomNiveau_3", n5."ID_TypeNiveau_5_Fk", g_type5."AbrGenerique";
COMMENT ON VIEW "geolocalisation"."V_Pop_N3_Couverte_Sites" IS 'Vue d''indicateurs population : somme des populations des sites par Zone de Sante et type de structure.';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."ID_Niveau_0" IS 'Identifiant de l’unité géographique de niveau 0. Expression projetée : n0."ID_Niveau_0".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."NomNiveau_0" IS 'Nom de l’unité géographique de niveau 0. Expression projetée : n0."NomNiveau_0".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."ID_Niveau_1" IS 'Identifiant de l’unité géographique de niveau 1. Expression projetée : n1."ID_Niveau_1".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."NomNiveau_1" IS 'Nom de l’unité géographique de niveau 1. Expression projetée : n1."NomNiveau_1".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."ID_Niveau_2" IS 'Identifiant de l’unité géographique de niveau 2. Expression projetée : n2."ID_Niveau_2".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."NomNiveau_2" IS 'Nom de l’unité géographique de niveau 2. Expression projetée : n2."NomNiveau_2".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."ID_Niveau_3" IS 'Identifiant de l’unité géographique de niveau 3. Expression projetée : n3."ID_Niveau_3".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."ID_TypeNiveau_5_Fk" IS 'Type de l’unité géographique dans le référentiel. Expression projetée : n5."ID_TypeNiveau_5_Fk".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."Type_Niveau_5" IS 'Abréviation du type d’unité de niveau 5 dans le référentiel. Expression projetée : COALESCE(g_type5."AbrGenerique", '' ''::character varying) AS "Type_Niveau_5".';
COMMENT ON COLUMN "geolocalisation"."V_Pop_N3_Couverte_Sites"."Pop_Cum_Sites" IS 'Somme des populations déclarées des sites rattachés via une aire de santé, par zone/type de site ; pas une population dédupliquée de personnes. Expression projetée : sum(COALESCE(n5."PopulationNiveau_5", 0::numeric)) AS "Pop_Cum_Sites".';
CREATE OR REPLACE PROCEDURE logistique.ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying)
 LANGUAGE plpgsql
AS $procedure$
DECLARE v_op text;
v_old_abr_type text;
v_new_abr_type text;
v_oper_stock_old varchar(1);
v_oper_stock_new varchar(1);
v_detail record;
BEGIN v_op := upper(trim(p_operation));
IF v_op IN ('INSERT', 'UPDATE') THEN PERFORM logistique.fn_assert_generique_category(
    p_new_id_type_cmd,
    64,
    format('ps_crud_commande(%s)', v_op),
    'ID_TypeCmdFk'
);
PERFORM logistique.fn_assert_generique_category(
    p_new_id_statut_cmd,
    28,
    format('ps_crud_commande(%s)', v_op),
    'ID_StatutCmdFk'
);
PERFORM logistique.fn_assert_generique_category(
    p_new_id_condition_paiement,
    37,
    format('ps_crud_commande(%s)', v_op),
    'ID_ConditionPaiementFk'
);
PERFORM logistique.fn_assert_generique_category(
    p_new_id_mode_paiement,
    36,
    format('ps_crud_commande(%s)', v_op),
    'ID_ModePaiementFk'
);
END IF;
IF v_op = 'INSERT' THEN RETURN;
END IF;
IF v_op = 'UPDATE' THEN IF p_new_id_type_cmd IS NULL THEN RAISE EXCEPTION 'ps_crud_commande(UPDATE) : nouveau ID_TypeCmdFk NULL pour commande %.',
p_id_commande;
END IF;
IF p_old_id_type_cmd IS NOT DISTINCT
FROM p_new_id_type_cmd THEN RETURN;
END IF;
IF p_old_id_type_cmd IS NULL THEN RAISE EXCEPTION 'ps_crud_commande(UPDATE) : ancien ID_TypeCmdFk NULL pour commande %, realignement impossible.',
p_id_commande;
END IF;
SELECT g."AbrGenerique" INTO v_old_abr_type
FROM referentiel."T_Generique" g
WHERE g."ID_Generique" = p_old_id_type_cmd
    AND g."ID_CategorieGeneriqueFk" = 64
LIMIT 1;
IF NOT FOUND THEN RAISE EXCEPTION 'ps_crud_commande(UPDATE) : ancien type de commande % introuvable ou hors categorie 64.',
p_old_id_type_cmd;
END IF;
SELECT g."AbrGenerique" INTO v_new_abr_type
FROM referentiel."T_Generique" g
WHERE g."ID_Generique" = p_new_id_type_cmd
    AND g."ID_CategorieGeneriqueFk" = 64
LIMIT 1;
IF NOT FOUND THEN RAISE EXCEPTION 'ps_crud_commande(UPDATE) : nouveau type de commande % introuvable ou hors categorie 64.',
p_new_id_type_cmd;
END IF;
IF v_old_abr_type ILIKE 'entr%' THEN v_oper_stock_old := '-';
ELSIF v_old_abr_type ILIKE 'sort%' THEN v_oper_stock_old := '+';
ELSE RAISE EXCEPTION 'ps_crud_commande(UPDATE) : ancien type non gere (ID_TypeCmdFk=%, Abr=%).',
p_old_id_type_cmd,
v_old_abr_type;
END IF;
IF v_new_abr_type ILIKE 'entr%' THEN v_oper_stock_new := '+';
ELSIF v_new_abr_type ILIKE 'sort%' THEN v_oper_stock_new := '-';
ELSE RAISE EXCEPTION 'ps_crud_commande(UPDATE) : nouveau type non gere (ID_TypeCmdFk=%, Abr=%).',
p_new_id_type_cmd,
v_new_abr_type;
END IF;
FOR v_detail IN
SELECT cd."ID_ArticleFk",
    COALESCE(cd."QteCmdDetail", 0)::numeric AS qte
FROM logistique."T_CommandeDetail" cd
WHERE cd."ID_CmdFk" = p_id_commande LOOP IF v_detail.qte <= 0 THEN RAISE EXCEPTION 'ps_crud_commande(UPDATE) : quantite invalide pour commande %, article %, qte=%.',
    p_id_commande,
    v_detail."ID_ArticleFk",
    v_detail.qte;
END IF;
IF v_detail.qte <> trunc(v_detail.qte) THEN RAISE EXCEPTION 'ps_crud_commande(UPDATE) : QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier pour commande %, article %.',
v_detail.qte,
p_id_commande,
v_detail."ID_ArticleFk";
END IF;
PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
CALL logistique.ps_update_qte_article(
    v_detail."ID_ArticleFk",
    v_detail.qte,
    v_oper_stock_old
);
CALL logistique.ps_update_qte_article(
    v_detail."ID_ArticleFk",
    v_detail.qte,
    v_oper_stock_new
);
PERFORM set_config(
    'logistique.skip_article_report_mvt',
    'off',
    true
);
END LOOP;
PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);
UPDATE logistique."T_Mouvement"
SET "ID_TypeMvtFk" = p_new_id_type_cmd
WHERE "ID_cmdFk" = p_id_commande;
PERFORM set_config(
    'logistique.allow_t_mouvement_write',
    'off',
    true
);
RETURN;
END IF;
IF v_op = 'DELETE' THEN RETURN;
END IF;
END;
$procedure$
;
COMMENT ON PROCEDURE "logistique"."ps_crud_commande"(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying) IS 'Contrôle les catégories 64/type, 28/statut, 37/condition et 36/mode. En cas de changement de type, annule puis réapplique l’effet des lignes sur le stock et réaligne le type des mouvements. Exige des quantités entières ; INSERT seul n’affecte pas le stock.';
CREATE OR REPLACE PROCEDURE logistique.ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying)
 LANGUAGE plpgsql
AS $procedure$
DECLARE v_op text;
v_old_type_cmd_id integer;
v_old_abr_type text;
v_new_type_cmd_id integer;
v_new_abr_type text;
v_oper_stock_old varchar(1);
v_oper_stock_new varchar(1);
v_new_pu_mvt numeric(12, 2);
BEGIN v_op := upper(trim(p_operation));
IF v_op = 'INSERT' THEN IF p_new_qte IS NULL
OR p_new_qte <= 0 THEN RAISE EXCEPTION 'ps_crud_commandeDetail(INSERT) : QteCmdDetail invalide (=%).',
p_new_qte;
END IF;
IF p_new_qte <> trunc(p_new_qte) THEN RAISE EXCEPTION 'ps_crud_commandeDetail(INSERT) : QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier.',
p_new_qte;
END IF;
SELECT c."ID_TypeCmdFk",
    g."AbrGenerique" INTO v_new_type_cmd_id,
    v_new_abr_type
FROM logistique."T_Commande" c
    JOIN referentiel."T_Generique" g ON c."ID_TypeCmdFk" = g."ID_Generique"
    AND g."ID_CategorieGeneriqueFk" = 64
WHERE c."ID_Commande" = p_new_cmd_fk
LIMIT 1;
IF NOT FOUND THEN RAISE EXCEPTION 'ps_crud_commandeDetail(INSERT) : commande % introuvable ou sans type.',
p_new_cmd_fk;
END IF;
IF v_new_abr_type ILIKE 'entr%' THEN v_oper_stock_new := '+';
ELSIF v_new_abr_type ILIKE 'sort%' THEN v_oper_stock_new := '-';
ELSE RAISE EXCEPTION 'ps_crud_commandeDetail(INSERT) : type de commande non gere (ID_TypeCmdFk=%).',
v_new_type_cmd_id;
END IF;
PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
CALL logistique.ps_update_qte_article(p_new_article_fk, p_new_qte, v_oper_stock_new);
PERFORM set_config(
    'logistique.skip_article_report_mvt',
    'off',
    true
);
v_new_pu_mvt := COALESCE(p_new_pu, 0)::numeric(12, 2);
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
        v_new_type_cmd_id,
        p_new_article_fk,
        p_new_cmd_fk,
        now()::timestamp without time zone,
        now()::timestamp without time zone,
        p_new_qte::integer,
        v_new_pu_mvt
    );
PERFORM set_config(
    'logistique.allow_t_mouvement_write',
    'off',
    true
);
RETURN;
END IF;
IF v_op = 'UPDATE' THEN IF p_old_cmd_fk IS NOT DISTINCT
FROM p_new_cmd_fk
    AND p_old_article_fk IS NOT DISTINCT
FROM p_new_article_fk
    AND p_old_qte IS NOT DISTINCT
FROM p_new_qte THEN IF p_old_pu IS DISTINCT
FROM p_new_pu THEN PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);
UPDATE logistique."T_Mouvement"
SET "PUMvt" = COALESCE(p_new_pu, 0)::numeric(12, 2)
WHERE "ID_ArticleFk" = p_new_article_fk
    AND "ID_cmdFk" = p_new_cmd_fk;
PERFORM set_config(
    'logistique.allow_t_mouvement_write',
    'off',
    true
);
END IF;
RETURN;
END IF;
IF p_new_qte IS NULL
OR p_new_qte <= 0 THEN RAISE EXCEPTION 'ps_crud_commandeDetail(UPDATE) : nouvelle QteCmdDetail invalide (=%).',
p_new_qte;
END IF;
IF p_new_qte <> trunc(p_new_qte) THEN RAISE EXCEPTION 'ps_crud_commandeDetail(UPDATE) : nouvelle QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier.',
p_new_qte;
END IF;
IF p_old_cmd_fk IS NOT NULL
AND p_old_article_fk IS NOT NULL
AND p_old_qte IS NOT NULL THEN IF p_old_qte <> trunc(p_old_qte) THEN RAISE EXCEPTION 'ps_crud_commandeDetail(UPDATE) : ancienne QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier.',
p_old_qte;
END IF;
SELECT c."ID_TypeCmdFk",
    g."AbrGenerique" INTO v_old_type_cmd_id,
    v_old_abr_type
FROM logistique."T_Commande" c
    JOIN referentiel."T_Generique" g ON c."ID_TypeCmdFk" = g."ID_Generique"
    AND g."ID_CategorieGeneriqueFk" = 64
WHERE c."ID_Commande" = p_old_cmd_fk
LIMIT 1;
IF NOT FOUND THEN
SELECT m."ID_TypeMvtFk",
    g."AbrGenerique" INTO v_old_type_cmd_id,
    v_old_abr_type
FROM logistique."T_Mouvement" m
    JOIN referentiel."T_Generique" g ON m."ID_TypeMvtFk" = g."ID_Generique"
    AND g."ID_CategorieGeneriqueFk" = 64
WHERE m."ID_ArticleFk" = p_old_article_fk
    AND m."ID_cmdFk" = p_old_cmd_fk
LIMIT 1;
END IF;
IF NOT FOUND THEN RAISE EXCEPTION 'ps_crud_commandeDetail(UPDATE) : ancienne commande % introuvable.',
p_old_cmd_fk;
END IF;
IF v_old_abr_type ILIKE 'entr%' THEN v_oper_stock_old := '-';
ELSIF v_old_abr_type ILIKE 'sort%' THEN v_oper_stock_old := '+';
ELSE RAISE EXCEPTION 'ps_crud_commandeDetail(UPDATE) : ancien type non gere (ID_TypeCmdFk=%).',
v_old_type_cmd_id;
END IF;
PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
CALL logistique.ps_update_qte_article(p_old_article_fk, p_old_qte, v_oper_stock_old);
PERFORM set_config(
    'logistique.skip_article_report_mvt',
    'off',
    true
);
PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);
DELETE FROM logistique."T_Mouvement"
WHERE "ID_TypeMvtFk" = v_old_type_cmd_id
    AND "ID_ArticleFk" = p_old_article_fk
    AND "ID_cmdFk" = p_old_cmd_fk;
PERFORM set_config(
    'logistique.allow_t_mouvement_write',
    'off',
    true
);
END IF;
SELECT c."ID_TypeCmdFk",
    g."AbrGenerique" INTO v_new_type_cmd_id,
    v_new_abr_type
FROM logistique."T_Commande" c
    JOIN referentiel."T_Generique" g ON c."ID_TypeCmdFk" = g."ID_Generique"
    AND g."ID_CategorieGeneriqueFk" = 64
WHERE c."ID_Commande" = p_new_cmd_fk
LIMIT 1;
IF NOT FOUND THEN RAISE EXCEPTION 'ps_crud_commandeDetail(UPDATE) : nouvelle commande % introuvable.',
p_new_cmd_fk;
END IF;
IF v_new_abr_type ILIKE 'entr%' THEN v_oper_stock_new := '+';
ELSIF v_new_abr_type ILIKE 'sort%' THEN v_oper_stock_new := '-';
ELSE RAISE EXCEPTION 'ps_crud_commandeDetail(UPDATE) : nouveau type non gere (ID_TypeCmdFk=%).',
v_new_type_cmd_id;
END IF;
PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
CALL logistique.ps_update_qte_article(p_new_article_fk, p_new_qte, v_oper_stock_new);
PERFORM set_config(
    'logistique.skip_article_report_mvt',
    'off',
    true
);
v_new_pu_mvt := COALESCE(p_new_pu, 0)::numeric(12, 2);
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
        v_new_type_cmd_id,
        p_new_article_fk,
        p_new_cmd_fk,
        now()::timestamp without time zone,
        now()::timestamp without time zone,
        p_new_qte::integer,
        v_new_pu_mvt
    );
PERFORM set_config(
    'logistique.allow_t_mouvement_write',
    'off',
    true
);
RETURN;
END IF;
IF v_op = 'DELETE' THEN IF p_old_cmd_fk IS NULL
OR p_old_article_fk IS NULL
OR p_old_qte IS NULL THEN RAISE EXCEPTION 'ps_crud_commandeDetail(DELETE) : parametres OLD incomplets.';
END IF;
IF p_old_qte <> trunc(p_old_qte) THEN RAISE EXCEPTION 'ps_crud_commandeDetail(DELETE) : ancienne QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier.',
p_old_qte;
END IF;
SELECT c."ID_TypeCmdFk",
    g."AbrGenerique" INTO v_old_type_cmd_id,
    v_old_abr_type
FROM logistique."T_Commande" c
    JOIN referentiel."T_Generique" g ON c."ID_TypeCmdFk" = g."ID_Generique"
    AND g."ID_CategorieGeneriqueFk" = 64
WHERE c."ID_Commande" = p_old_cmd_fk
LIMIT 1;
IF NOT FOUND THEN
SELECT m."ID_TypeMvtFk",
    g."AbrGenerique" INTO v_old_type_cmd_id,
    v_old_abr_type
FROM logistique."T_Mouvement" m
    JOIN referentiel."T_Generique" g ON m."ID_TypeMvtFk" = g."ID_Generique"
    AND g."ID_CategorieGeneriqueFk" = 64
WHERE m."ID_ArticleFk" = p_old_article_fk
    AND m."ID_cmdFk" = p_old_cmd_fk
LIMIT 1;
END IF;
IF NOT FOUND THEN RAISE EXCEPTION 'ps_crud_commandeDetail(DELETE) : commande % introuvable.',
p_old_cmd_fk;
END IF;
IF v_old_abr_type ILIKE 'entr%' THEN v_oper_stock_old := '-';
ELSIF v_old_abr_type ILIKE 'sort%' THEN v_oper_stock_old := '+';
ELSE RAISE EXCEPTION 'ps_crud_commandeDetail(DELETE) : type non gere (ID_TypeCmdFk=%).',
v_old_type_cmd_id;
END IF;
PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
CALL logistique.ps_update_qte_article(p_old_article_fk, p_old_qte, v_oper_stock_old);
PERFORM set_config(
    'logistique.skip_article_report_mvt',
    'off',
    true
);
PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);
DELETE FROM logistique."T_Mouvement"
WHERE "ID_TypeMvtFk" = v_old_type_cmd_id
    AND "ID_ArticleFk" = p_old_article_fk
    AND "ID_cmdFk" = p_old_cmd_fk;
PERFORM set_config(
    'logistique.allow_t_mouvement_write',
    'off',
    true
);
RETURN;
END IF;
END;
$procedure$
;
COMMENT ON PROCEDURE "logistique"."ps_crud_commandedetail"(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying) IS 'Applique les effets d’une ligne selon INSERT/UPDATE/DELETE : stock, annulation de l’ancien effet, création ou suppression des mouvements. Un changement de prix seul actualise PUMvt sans changer le stock. Quantité strictement positive et entière ; prix NULL historisé à zéro.';
CREATE OR REPLACE FUNCTION logistique.tr_delete_commande()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    CALL logistique.ps_crud_commande(OLD."ID_Commande", OLD."ID_TypeCmdFk", NULL, 'DELETE');
    RETURN OLD;
END;
$function$
;
COMMENT ON FUNCTION "logistique"."tr_delete_commande"() IS 'Fonction historique de suppression, non raccordée à un trigger lors du relevé du 24/10/2026. Son appel à ps_crud_commande utilise une ancienne signature à quatre arguments, distincte de la procédure actuellement installée à sept arguments ; ne pas la présenter comme un parcours actif.';
CREATE OR REPLACE FUNCTION systeme.audit_log_function()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    entite_id INTEGER;
BEGIN
    -- Récupération de l'IdEntiteFk si la table concernée en possède une
    SELECT CASE 
        WHEN TG_OP IN ('DELETE', 'UPDATE') THEN OLD."IdEntiteFk"
        WHEN TG_OP = 'INSERT'             THEN NEW."IdEntiteFk"
        ELSE NULL 
    END INTO entite_id
    FROM (SELECT 1) AS dummy  -- Hack pour éviter les erreurs si la colonne n'existe pas
    WHERE EXISTS (
        SELECT 1
        FROM information_schema.columns 
        WHERE table_name  = TG_TABLE_NAME
          AND column_name = 'IdEntiteFk'
    );
    
    -- Insertion dans T_Audit_Log
    INSERT INTO systeme."T_Audit_Log" (
        "TableName",
        "Operation",
        "OldData",
        "NewData",
        "ChangedAt",
        "IdEntiteFk"
    )
    VALUES (
        TG_TABLE_NAME,  -- Nom de la table modifiée
        TG_OP,          -- Type d’opération (INSERT, UPDATE, DELETE)
        CASE WHEN TG_OP IN ('DELETE', 'UPDATE') THEN row_to_json(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) ELSE NULL END,
        NOW(),          -- Date et heure de modification
        entite_id       -- IdEntiteFk récupéré
    );
    
    RETURN NULL;
END;
$function$
;
COMMENT ON FUNCTION "systeme"."audit_log_function"() IS 'Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';
CREATE OR REPLACE FUNCTION systeme.notify_licence_expiry()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE 
    days_remaining INT;
    user_id        INT;
    type_notif     INT;
BEGIN
    -- Nombre de jours restant avant l'expiration
    SELECT DATE_PART('day', NEW."DateFin" - NOW())
    INTO days_remaining;

    IF days_remaining = 7 THEN
        -- Récupérer un utilisateur "Admin Entité" de l'entité
        SELECT u."IdUser"
        INTO user_id
        FROM systeme."T_Utilisateurs" u
        JOIN systeme."T_Entite"      e ON e."IdEntite"     = u."IdEntiteFk"
        WHERE e."IdEntite" = NEW."IdEntiteFk"
          AND u."IdRoleFk" = (
              SELECT "ID_Generique"
              FROM referentiel."T_Generique"
              WHERE "NomGenerique" = 'Admin Entité'
              LIMIT 1
          )
        LIMIT 1;

        -- Type de communication "Notification"
        SELECT "ID_Generique"
        INTO type_notif
        FROM referentiel."T_Generique"
        WHERE "NomGenerique" = 'Notification'
        LIMIT 1;

        IF user_id IS NOT NULL AND type_notif IS NOT NULL THEN
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
                user_id,
                type_notif,
                'Votre licence expirera dans 7 jours. Veuillez la renouveler.',
                NOW(),
                TRUE,
                FALSE,
                NEW."IdEntiteFk"
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;
COMMENT ON FUNCTION "systeme"."notify_licence_expiry"() IS 'Après INSERT/UPDATE de licence, crée une notification pour un administrateur d’entité si DATE_PART(day, DateFin - NOW()) vaut 7 et si destinataire/type Notification sont trouvés. Ce trigger n’est pas une tâche quotidienne et ne s’exécute pas du seul fait du passage du temps.';
CREATE OR REPLACE FUNCTION systeme.prevent_multiple_active_licenses()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    existing_count INT;
BEGIN
    SELECT COUNT(*) INTO existing_count 
    FROM systeme."T_Licence"
    WHERE "IdEntiteFk"     = NEW."IdEntiteFk"
      AND "ExpireeLicence" = FALSE;

    IF existing_count > 0 THEN
        RAISE EXCEPTION 'Cette entité possède déjà une licence active.';
    END IF;

    RETURN NEW;
END;
$function$
;
COMMENT ON FUNCTION "systeme"."prevent_multiple_active_licenses"() IS 'Avant INSERT de licence, refuse l’ajout s’il existe une licence de la même entité avec ExpireeLicence = false. Ne contrôle pas les UPDATE ni ValideLicence dans cette fonction.';
CREATE OR REPLACE FUNCTION systeme.update_licence_status()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW."DateFin" < NOW() THEN
        NEW."ExpireeLicence" := TRUE;
    ELSE
        NEW."ExpireeLicence" := FALSE;
    END IF;

    RETURN NEW;
END;
$function$
;
COMMENT ON FUNCTION "systeme"."update_licence_status"() IS 'Avant INSERT/UPDATE de licence, fixe ExpireeLicence selon DateFin < NOW() ; une date NULL suit la branche false. Aucun recalcul périodique indépendant d’une écriture.';
DROP TRIGGER IF EXISTS trigger_prevent_multiple_licenses ON systeme."T_Licence";
CREATE TRIGGER trigger_prevent_multiple_licenses BEFORE INSERT ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.prevent_multiple_active_licenses();
COMMENT ON TRIGGER trigger_prevent_multiple_licenses ON systeme."T_Licence" IS 'BEFORE INSERT sur "systeme"."T_Licence", pour chaque ligne. Appelle "systeme"."prevent_multiple_active_licenses" : Avant INSERT de licence, refuse l’ajout s’il existe une licence de la même entité avec ExpireeLicence = false. Ne contrôle pas les UPDATE ni ValideLicence dans cette fonction.';
ALTER TABLE "logistique"."T_Article" DROP CONSTRAINT IF EXISTS "ck_article_prix_positifs";
ALTER TABLE "logistique"."T_CommandeDetail" DROP CONSTRAINT IF EXISTS "ck_ligne_prix_positif";
ALTER TABLE "communication"."T_Chat" DROP CONSTRAINT IF EXISTS "ck_chat_contenu_non_vide";
DROP INDEX IF EXISTS logistique.uq_mouvement_ligne_commande;
ALTER TABLE systeme."T_Licence" ALTER COLUMN "IdLicence" DROP IDENTITY IF EXISTS;
COMMENT ON COLUMN systeme."T_Licence"."IdLicence" IS 'Identifiant de la licence.';
DROP FUNCTION IF EXISTS referentiel.fn_guard_sens_stock();
DROP FUNCTION IF EXISTS communication.fn_lock_discussion_message();
DROP FUNCTION IF EXISTS communication.fn_sync_dernier_message();
DROP FUNCTION IF EXISTS systeme.fn_audit_sans_secrets(jsonb);
COMMIT;
