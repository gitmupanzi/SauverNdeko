-- Extrait canonique du catalogue installé le 24/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
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
