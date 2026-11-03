-- Extrait canonique du catalogue vérifié le 03/11/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_LotArticleStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_LotArticleStock" AS
SELECT
    NULL::integer AS "ID_LotArticle",
    NULL::integer AS "ID_ArticleFk",
    NULL::character varying(100) AS "NumeroLot",
    NULL::date AS "DatePeremptionLot",
    NULL::boolean AS "Actif",
    NULL::timestamp with time zone AS "CreeLe",
    NULL::numeric AS "StockLot",
    NULL::numeric AS "QuantiteEntree",
    NULL::numeric AS "QuantiteSortie",
    NULL::integer AS "ID_DeviseFk",
    NULL::text AS "DeviseCode",
    NULL::text AS "DeviseLibelle",
    NULL::text AS "EtatPeremptionLot",
    NULL::boolean AS "EstPerime",
    NULL::boolean AS "EstProche",
    NULL::integer AS "SeuilAlerteJours",
    NULL::boolean AS "BloquerLotsPerimes";

--
-- Name: VIEW "V_LotArticleStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_LotArticleStock" IS 'Stock restant par lot avec conservation et politique d’entreprise ; l’état d’un lot épuisé reste historique et ne déclenche pas une alerte Article.';

--
-- Name: COLUMN "V_LotArticleStock"."ID_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."ID_LotArticle" IS 'Conservation du stock : ID_LotArticle, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."ID_ArticleFk" IS 'Conservation du stock : ID_ArticleFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."NumeroLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."NumeroLot" IS 'Conservation du stock : NumeroLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."DatePeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."DatePeremptionLot" IS 'Conservation du stock : DatePeremptionLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."Actif" IS 'Conservation du stock : Actif, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."CreeLe" IS 'Conservation du stock : CreeLe, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."StockLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."StockLot" IS 'Conservation du stock : StockLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."QuantiteEntree"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."QuantiteEntree" IS 'Conservation du stock : QuantiteEntree, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."QuantiteSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."QuantiteSortie" IS 'Conservation du stock : QuantiteSortie, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."ID_DeviseFk" IS 'Conservation du stock : ID_DeviseFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."DeviseCode" IS 'Conservation du stock : DeviseCode, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."DeviseLibelle" IS 'Conservation du stock : DeviseLibelle, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."EtatPeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."EtatPeremptionLot" IS 'Conservation du stock : EtatPeremptionLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."EstPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."EstPerime" IS 'Conservation du stock : EstPerime, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."EstProche"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."EstProche" IS 'Conservation du stock : EstProche, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."SeuilAlerteJours"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."SeuilAlerteJours" IS 'Conservation du stock : SeuilAlerteJours, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotArticleStock"."BloquerLotsPerimes"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotArticleStock"."BloquerLotsPerimes" IS 'Conservation du stock : BloquerLotsPerimes, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: V_LotDisponibilite; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_LotDisponibilite" AS
 SELECT l."ID_LotArticle",
    l."ID_ArticleFk",
    l."NumeroLot",
    l."DatePeremptionLot",
    l."Actif",
    l."CreeLe",
    l."StockLot",
    l."QuantiteEntree",
    l."QuantiteSortie",
    l."ID_DeviseFk",
    l."DeviseCode",
    l."DeviseLibelle",
    a."IdEntiteFk",
    a."NomArticle",
    a."ID_UniteFk",
    u."AbrGenerique" AS "Unite",
        CASE
            WHEN (l."DatePeremptionLot" IS NULL) THEN 'Non renseignée'::text
            WHEN (l."DatePeremptionLot" < ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) THEN 'Périmé'::text
            WHEN (l."DatePeremptionLot" <= (((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date + COALESCE(a."NbreJoursAlerteArticle", (e."AlertePeremptionJours")::integer, 30))) THEN 'Proche'::text
            ELSE 'Valide'::text
        END AS "EtatPeremptionLot",
    ((l."DatePeremptionLot" < ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) IS TRUE) AS "EstPerime",
    (((l."DatePeremptionLot" >= ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) AND (l."DatePeremptionLot" <= (((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date + COALESCE(a."NbreJoursAlerteArticle", (e."AlertePeremptionJours")::integer, 30)))) IS TRUE) AS "EstProche",
    COALESCE(a."NbreJoursAlerteArticle", (e."AlertePeremptionJours")::integer, 30) AS "SeuilAlerteJours",
    e."BloquerLotsPerimes"
   FROM (((logistique."V_LotArticleStock" l
     JOIN logistique."T_Article" a ON ((a."ID_Article" = l."ID_ArticleFk")))
     LEFT JOIN referentiel."T_Generique" u ON ((u."ID_Generique" = a."ID_UniteFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = a."IdEntiteFk")));

--
-- Name: VIEW "V_LotDisponibilite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_LotDisponibilite" IS 'Stock réel par lot, seuil article ou entreprise, état de péremption et politique de sortie ; un lot épuisé conserve son historique.';

--
-- Name: COLUMN "V_LotDisponibilite"."ID_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."ID_LotArticle" IS 'Conservation du stock : ID_LotArticle, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."ID_ArticleFk" IS 'Conservation du stock : ID_ArticleFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."NumeroLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."NumeroLot" IS 'Conservation du stock : NumeroLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."DatePeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."DatePeremptionLot" IS 'Conservation du stock : DatePeremptionLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."Actif" IS 'Conservation du stock : Actif, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."CreeLe" IS 'Conservation du stock : CreeLe, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."StockLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."StockLot" IS 'Conservation du stock : StockLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."QuantiteEntree"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."QuantiteEntree" IS 'Conservation du stock : QuantiteEntree, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."QuantiteSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."QuantiteSortie" IS 'Conservation du stock : QuantiteSortie, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."ID_DeviseFk" IS 'Conservation du stock : ID_DeviseFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."DeviseCode" IS 'Conservation du stock : DeviseCode, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."DeviseLibelle" IS 'Conservation du stock : DeviseLibelle, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."IdEntiteFk" IS 'Conservation du stock : IdEntiteFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."NomArticle" IS 'Conservation du stock : NomArticle, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."ID_UniteFk" IS 'Conservation du stock : ID_UniteFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."Unite" IS 'Conservation du stock : Unite, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."EtatPeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."EtatPeremptionLot" IS 'Conservation du stock : EtatPeremptionLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."EstPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."EstPerime" IS 'Conservation du stock : EstPerime, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."EstProche"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."EstProche" IS 'Conservation du stock : EstProche, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."SeuilAlerteJours"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."SeuilAlerteJours" IS 'Conservation du stock : SeuilAlerteJours, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_LotDisponibilite"."BloquerLotsPerimes"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_LotDisponibilite"."BloquerLotsPerimes" IS 'Conservation du stock : BloquerLotsPerimes, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: V_ArticlePeremption; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_ArticlePeremption" AS
 WITH lots AS (
         SELECT "V_LotDisponibilite"."ID_ArticleFk",
            sum("V_LotDisponibilite"."StockLot") AS total,
            COALESCE(sum("V_LotDisponibilite"."StockLot") FILTER (WHERE (("V_LotDisponibilite"."StockLot" > (0)::numeric) AND "V_LotDisponibilite"."EstPerime")), (0)::numeric) AS perime,
            COALESCE(sum("V_LotDisponibilite"."StockLot") FILTER (WHERE (("V_LotDisponibilite"."StockLot" > (0)::numeric) AND "V_LotDisponibilite"."EstProche")), (0)::numeric) AS proche,
            COALESCE(sum("V_LotDisponibilite"."StockLot") FILTER (WHERE (("V_LotDisponibilite"."StockLot" > (0)::numeric) AND ("V_LotDisponibilite"."DatePeremptionLot" IS NULL))), (0)::numeric) AS sansdate,
            min("V_LotDisponibilite"."DatePeremptionLot") FILTER (WHERE ("V_LotDisponibilite"."StockLot" > (0)::numeric)) AS dateproche,
            count(*) FILTER (WHERE (("V_LotDisponibilite"."StockLot" > (0)::numeric) AND "V_LotDisponibilite"."EstPerime")) AS lotsperimes,
            count(*) FILTER (WHERE (("V_LotDisponibilite"."StockLot" > (0)::numeric) AND "V_LotDisponibilite"."EstProche")) AS lotsproches
           FROM logistique."V_LotDisponibilite"
          GROUP BY "V_LotDisponibilite"."ID_ArticleFk"
        ), stocks AS (
         SELECT a."ID_Article",
            a."IdEntiteFk",
            a."QteArticle",
            (a."DatePeremptionArticle")::date AS generale,
            (a."DatePeremptionAlerteArticle")::date AS alertegenerale,
            COALESCE(a."NbreJoursAlerteArticle", (e."AlertePeremptionJours")::integer, 30) AS seuil,
            GREATEST((COALESCE(a."QteArticle", (0)::numeric) - COALESCE(l.total, (0)::numeric)), (0)::numeric) AS sanslot,
            COALESCE(l.perime, (0)::numeric) AS lotperime,
            COALESCE(l.proche, (0)::numeric) AS lotproche,
            COALESCE(l.sansdate, (0)::numeric) AS lotsansdate,
            l.dateproche,
            COALESCE(l.lotsperimes, (0)::bigint) AS lotsperimes,
            COALESCE(l.lotsproches, (0)::bigint) AS lotsproches
           FROM ((logistique."T_Article" a
             LEFT JOIN lots l ON ((l."ID_ArticleFk" = a."ID_Article")))
             LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = a."IdEntiteFk")))
        ), classement AS (
         SELECT stocks."ID_Article",
            stocks."IdEntiteFk",
            stocks."QteArticle",
            stocks.generale,
            stocks.alertegenerale,
            stocks.seuil,
            stocks.sanslot,
            stocks.lotperime,
            stocks.lotproche,
            stocks.lotsansdate,
            stocks.dateproche,
            stocks.lotsperimes,
            stocks.lotsproches,
            (stocks.lotperime +
                CASE
                    WHEN (stocks.generale < ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) THEN stocks.sanslot
                    ELSE (0)::numeric
                END) AS perime,
            (stocks.lotproche +
                CASE
                    WHEN ((stocks.generale >= ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) AND ((stocks.generale <= (((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date + stocks.seuil)) OR (stocks.alertegenerale <= ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date))) THEN stocks.sanslot
                    ELSE (0)::numeric
                END) AS proche,
            (stocks.lotsansdate +
                CASE
                    WHEN (stocks.generale IS NULL) THEN stocks.sanslot
                    ELSE (0)::numeric
                END) AS sansdate,
            LEAST(stocks.dateproche,
                CASE
                    WHEN (stocks.sanslot > (0)::numeric) THEN stocks.generale
                    ELSE NULL::date
                END) AS prochaine
           FROM stocks
        )
 SELECT "ID_Article",
    "IdEntiteFk",
    perime AS "StockPerime",
    proche AS "StockProchePeremption",
    sansdate AS "StockSansDatePeremption",
    sanslot AS "StockSansLot",
    prochaine AS "DateProchainePeremption",
    lotsperimes AS "LotsPerimes",
    lotsproches AS "LotsProchesPeremption",
    seuil AS "SeuilAlerteJours",
    (perime > (0)::numeric) AS "EstPerime",
    (proche > (0)::numeric) AS "EstAlertePeremption",
        CASE
            WHEN (perime > (0)::numeric) THEN 'Périmé'::text
            WHEN (proche > (0)::numeric) THEN 'Alerte péremption'::text
            WHEN (COALESCE("QteArticle", (0)::numeric) <= (0)::numeric) THEN 'Sans stock'::text
            WHEN (sansdate > (0)::numeric) THEN 'Non renseignée'::text
            ELSE 'Valide'::text
        END AS "EtatPeremption",
    (prochaine - ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) AS "JoursAvantPeremption",
        CASE
            WHEN (perime > (0)::numeric) THEN 1
            WHEN (proche > (0)::numeric) THEN 2
            WHEN ((sansdate > (0)::numeric) OR (COALESCE("QteArticle", (0)::numeric) <= (0)::numeric)) THEN 4
            ELSE 3
        END AS "PrioritePeremption"
   FROM classement;

--
-- Name: VIEW "V_ArticlePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_ArticlePeremption" IS 'Situation exhaustive de conservation : uniquement les quantités encore en stock, tous lots y compris archivés, et le stock sans lot couvert par la date générale. Une même référence peut avoir simultanément du stock périmé et proche.';

--
-- Name: COLUMN "V_ArticlePeremption"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."ID_Article" IS 'Conservation du stock : ID_Article, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."IdEntiteFk" IS 'Conservation du stock : IdEntiteFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."StockPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."StockPerime" IS 'Conservation du stock : StockPerime, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."StockProchePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."StockProchePeremption" IS 'Conservation du stock : StockProchePeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."StockSansDatePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."StockSansDatePeremption" IS 'Conservation du stock : StockSansDatePeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."StockSansLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."StockSansLot" IS 'Conservation du stock : StockSansLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."DateProchainePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."DateProchainePeremption" IS 'Conservation du stock : DateProchainePeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."LotsPerimes"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."LotsPerimes" IS 'Conservation du stock : LotsPerimes, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."LotsProchesPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."LotsProchesPeremption" IS 'Conservation du stock : LotsProchesPeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."SeuilAlerteJours"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."SeuilAlerteJours" IS 'Conservation du stock : SeuilAlerteJours, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."EstPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."EstPerime" IS 'Conservation du stock : EstPerime, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."EstAlertePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."EstAlertePeremption" IS 'Conservation du stock : EstAlertePeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."EtatPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."EtatPeremption" IS 'Conservation du stock : EtatPeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."JoursAvantPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."JoursAvantPeremption" IS 'Conservation du stock : JoursAvantPeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_ArticlePeremption"."PrioritePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ArticlePeremption"."PrioritePeremption" IS 'Conservation du stock : PrioritePeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: V_Article; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Article" AS
 SELECT source_publication."ID_Article",
    source_publication."DateHeureAuto",
    source_publication."CodeArticleInterne",
    source_publication."CodeArticleExterne",
    source_publication."NomArticle",
    source_publication."RefArticle",
    source_publication."PhotoArticle",
    source_publication."ObsArticle",
    source_publication."ValideArticle",
    source_publication."ID_TypeArticleFk",
    source_publication."AbrTypeArticle",
    source_publication."TypeArticle",
    source_publication."ID_CategorieArticleFk",
    source_publication."AbrCategorieArticle",
    source_publication."CategorieArticle",
    source_publication."ID_UniteFk",
    source_publication."AbrUnite",
    source_publication."Unite",
    source_publication."QteArticle",
    source_publication."QteMinArticle",
    source_publication."QteACommander",
    source_publication."EtatStock",
    source_publication."EstRupture",
    source_publication."EstAlerteStock",
    source_publication."PrioriteStock",
    source_publication."PUArticle",
    source_publication."PVArticle",
    source_publication."ValeurStockAchat",
    source_publication."ValeurStockVente",
    source_publication."MargeUnitaire",
    source_publication."TauxMargePct",
    source_publication."DatePeremptionArticle",
    source_publication."DatePeremptionAlerteArticle",
    source_publication."NbreJoursAlerteArticle",
    source_publication."EtatPeremption",
    source_publication."JoursAvantPeremption",
    source_publication."EstPerime",
    source_publication."EstAlertePeremption",
    source_publication."PrioritePeremption",
    source_publication."ID_UserFK",
    source_publication."IdUser",
    source_publication."NomComplet",
    source_publication."EtatArticle",
    source_publication."PoidsUnitaire",
    source_publication."ID_UnitePoidsFk",
    source_publication."UnitePoids",
    source_publication."NombreLots",
    source_publication."StockVentileLots",
    source_publication."StockSansLot",
    source_publication."InformationArticle",
    source_publication."ID_DeviseFk",
    source_publication."DeviseCode",
    source_publication."DeviseLibelle",
    source_publication."IdEntiteFk",
    source_publication."StockPerime",
    source_publication."StockProchePeremption",
    source_publication."StockSansDatePeremption",
    source_publication."DateProchainePeremption",
    source_publication."LotsPerimes",
    source_publication."LotsProchesPeremption",
    source_publication."SeuilAlerteJours",
    article_publication."VisibleCatalogue"
   FROM (( SELECT source."ID_Article",
            source."DateHeureAuto",
            source."CodeArticleInterne",
            source."CodeArticleExterne",
            source."NomArticle",
            source."RefArticle",
            source."PhotoArticle",
            source."ObsArticle",
            source."ValideArticle",
            source."ID_TypeArticleFk",
            source."AbrTypeArticle",
            source."TypeArticle",
            source."ID_CategorieArticleFk",
            source."AbrCategorieArticle",
            source."CategorieArticle",
            source."ID_UniteFk",
            source."AbrUnite",
            source."Unite",
            source."QteArticle",
            source."QteMinArticle",
            source."QteACommander",
            source."EtatStock",
            source."EstRupture",
            source."EstAlerteStock",
            source."PrioriteStock",
            source."PUArticle",
            source."PVArticle",
            source."ValeurStockAchat",
            source."ValeurStockVente",
            source."MargeUnitaire",
            source."TauxMargePct",
            source."DatePeremptionArticle",
            source."DatePeremptionAlerteArticle",
            source."NbreJoursAlerteArticle",
            p."EtatPeremption",
            p."JoursAvantPeremption",
            p."EstPerime",
            p."EstAlertePeremption",
            p."PrioritePeremption",
            source."ID_UserFK",
            source."IdUser",
            source."NomComplet",
            source."EtatArticle",
            source."PoidsUnitaire",
            source."ID_UnitePoidsFk",
            source."UnitePoids",
            source."NombreLots",
            source."StockVentileLots",
            source."StockSansLot",
            source."InformationArticle",
            source."ID_DeviseFk",
            source."DeviseCode",
            source."DeviseLibelle",
            source."IdEntiteFk",
            p."StockPerime",
            p."StockProchePeremption",
            p."StockSansDatePeremption",
            p."DateProchainePeremption",
            p."LotsPerimes",
            p."LotsProchesPeremption",
            p."SeuilAlerteJours"
           FROM (( SELECT source_1."ID_Article",
                    source_1."DateHeureAuto",
                    source_1."CodeArticleInterne",
                    source_1."CodeArticleExterne",
                    source_1."NomArticle",
                    source_1."RefArticle",
                    source_1."PhotoArticle",
                    source_1."ObsArticle",
                    source_1."ValideArticle",
                    source_1."ID_TypeArticleFk",
                    source_1."AbrTypeArticle",
                    source_1."TypeArticle",
                    source_1."ID_CategorieArticleFk",
                    source_1."AbrCategorieArticle",
                    source_1."CategorieArticle",
                    source_1."ID_UniteFk",
                    source_1."AbrUnite",
                    source_1."Unite",
                    source_1."QteArticle",
                    source_1."QteMinArticle",
                    source_1."QteACommander",
                    source_1."EtatStock",
                    source_1."EstRupture",
                    source_1."EstAlerteStock",
                    source_1."PrioriteStock",
                    source_1."PUArticle",
                    source_1."PVArticle",
                    source_1."ValeurStockAchat",
                    source_1."ValeurStockVente",
                    source_1."MargeUnitaire",
                    source_1."TauxMargePct",
                    source_1."DatePeremptionArticle",
                    source_1."DatePeremptionAlerteArticle",
                    source_1."NbreJoursAlerteArticle",
                    source_1."EtatPeremption",
                    source_1."JoursAvantPeremption",
                    source_1."EstPerime",
                    source_1."EstAlertePeremption",
                    source_1."PrioritePeremption",
                    source_1."ID_UserFK",
                    source_1."IdUser",
                    source_1."NomComplet",
                    source_1."EtatArticle",
                    source_1."PoidsUnitaire",
                    source_1."ID_UnitePoidsFk",
                    source_1."UnitePoids",
                    source_1."NombreLots",
                    source_1."StockVentileLots",
                    source_1."StockSansLot",
                    source_1."InformationArticle",
                    source_1."ID_DeviseFk",
                    source_1."DeviseCode",
                    source_1."DeviseLibelle",
                    r."IdEntiteFk"
                   FROM (( SELECT historique."ID_Article",
                            historique."DateHeureAuto",
                            historique."CodeArticleInterne",
                            historique."CodeArticleExterne",
                            historique."NomArticle",
                            historique."RefArticle",
                            historique."PhotoArticle",
                            historique."ObsArticle",
                            historique."ValideArticle",
                            historique."ID_TypeArticleFk",
                            historique."AbrTypeArticle",
                            historique."TypeArticle",
                            historique."ID_CategorieArticleFk",
                            historique."AbrCategorieArticle",
                            historique."CategorieArticle",
                            historique."ID_UniteFk",
                            historique."AbrUnite",
                            historique."Unite",
                            historique."QteArticle",
                            historique."QteMinArticle",
                            historique."QteACommander",
                            historique."EtatStock",
                            historique."EstRupture",
                            historique."EstAlerteStock",
                            historique."PrioriteStock",
                            historique."PUArticle",
                            historique."PVArticle",
                            historique."ValeurStockAchat",
                            historique."ValeurStockVente",
                            historique."MargeUnitaire",
                            historique."TauxMargePct",
                            historique."DatePeremptionArticle",
                            historique."DatePeremptionAlerteArticle",
                            historique."NbreJoursAlerteArticle",
                            historique."EtatPeremption",
                            historique."JoursAvantPeremption",
                            historique."EstPerime",
                            historique."EstAlertePeremption",
                            historique."PrioritePeremption",
                            historique."ID_UserFK",
                            historique."IdUser",
                            historique."NomComplet",
                            historique."EtatArticle",
                            historique."PoidsUnitaire",
                            historique."ID_UnitePoidsFk",
                            historique."UnitePoids",
                            historique."NombreLots",
                            historique."StockVentileLots",
                            historique."StockSansLot",
                            historique."InformationArticle",
                            source_1_1."ID_DeviseFk",
                            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
                            (devise."NomGenerique")::text AS "DeviseLibelle"
                           FROM ((( SELECT a."ID_Article",
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
                                    (GREATEST((COALESCE(a."QteMinArticle", (0)::numeric) - COALESCE(a."QteArticle", (0)::numeric)), (0)::numeric))::numeric(14,3) AS "QteACommander",
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
END AS "EtatArticle",
                                    a."PoidsUnitaire",
                                    a."ID_UnitePoidsFk",
                                    ( SELECT g."AbrGenerique"
   FROM referentiel."T_Generique" g
  WHERE (g."ID_Generique" = a."ID_UnitePoidsFk")) AS "UnitePoids",
                                    ( SELECT (count(*))::integer AS count
   FROM logistique."T_LotArticle" l
  WHERE (l."ID_ArticleFk" = a."ID_Article")) AS "NombreLots",
                                    ( SELECT COALESCE(sum(l."StockLot"), (0)::numeric) AS "coalesce"
   FROM logistique."V_LotArticleStock" l
  WHERE (l."ID_ArticleFk" = a."ID_Article")) AS "StockVentileLots",
                                    (a."QteArticle" - ( SELECT COALESCE(sum(l."StockLot"), (0)::numeric) AS "coalesce"
   FROM logistique."V_LotArticleStock" l
  WHERE (l."ID_ArticleFk" = a."ID_Article"))) AS "StockSansLot",
                                    a."InformationArticle"
                                   FROM ((((logistique."T_Article" a
                                     LEFT JOIN referentiel."T_Generique" type_article ON ((a."ID_TypeArticleFk" = type_article."ID_Generique")))
                                     LEFT JOIN referentiel."T_Generique" categorie_article ON ((a."ID_CategorieArticleFk" = categorie_article."ID_Generique")))
                                     LEFT JOIN referentiel."T_Generique" unite ON ((a."ID_UniteFk" = unite."ID_Generique")))
                                     LEFT JOIN systeme."T_Utilisateurs" u ON ((a."ID_UserFK" = u."IdUser")))) historique
                             LEFT JOIN logistique."T_Article" source_1_1 ON ((source_1_1."ID_Article" = historique."ID_Article")))
                             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1_1."ID_DeviseFk")))) source_1
                     LEFT JOIN logistique."T_Article" r ON ((r."ID_Article" = source_1."ID_Article")))) source
             JOIN logistique."V_ArticlePeremption" p ON ((p."ID_Article" = source."ID_Article")))) source_publication
     JOIN logistique."T_Article" article_publication ON ((article_publication."ID_Article" = source_publication."ID_Article")));

--
-- Name: VIEW "V_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Article" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

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

COMMENT ON COLUMN logistique."V_Article"."AbrTypeArticle" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Article"."TypeArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."TypeArticle" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Article"."ID_CategorieArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_CategorieArticleFk" IS 'Catégorie de l’article dans la nomenclature de catégorie 40. Expression projetée : a."ID_CategorieArticleFk".';

--
-- Name: COLUMN "V_Article"."AbrCategorieArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."AbrCategorieArticle" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Article"."CategorieArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."CategorieArticle" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Article"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_UniteFk" IS 'Unité de référence de l’article, dans la nomenclature de catégorie 34. Expression projetée : a."ID_UniteFk".';

--
-- Name: COLUMN "V_Article"."AbrUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."AbrUnite" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Article"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."Unite" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

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

COMMENT ON COLUMN logistique."V_Article"."EtatPeremption" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : EtatPeremption.';

--
-- Name: COLUMN "V_Article"."JoursAvantPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."JoursAvantPeremption" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : JoursAvantPeremption.';

--
-- Name: COLUMN "V_Article"."EstPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EstPerime" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : EstPerime.';

--
-- Name: COLUMN "V_Article"."EstAlertePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."EstAlertePeremption" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : EstAlertePeremption.';

--
-- Name: COLUMN "V_Article"."PrioritePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."PrioritePeremption" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : PrioritePeremption.';

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
-- Name: COLUMN "V_Article"."PoidsUnitaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."PoidsUnitaire" IS 'Masse d’une unité de stock, inconnue si NULL.';

--
-- Name: COLUMN "V_Article"."ID_UnitePoidsFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_UnitePoidsFk" IS 'Unité de masse du poids unitaire.';

--
-- Name: COLUMN "V_Article"."UnitePoids"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."UnitePoids" IS 'Abréviation de l’unité de masse du référentiel.';

--
-- Name: COLUMN "V_Article"."NombreLots"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."NombreLots" IS 'Nombre de numéros de lot connus pour cet article, actifs ou archivés.';

--
-- Name: COLUMN "V_Article"."StockVentileLots"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."StockVentileLots" IS 'Stock courant identifié par numéro de lot, issu des mouvements ventilés.';

--
-- Name: COLUMN "V_Article"."StockSansLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."StockSansLot" IS 'Part du stock global encore dépourvue de numéro de lot ; aucune attribution inventée.';

--
-- Name: COLUMN "V_Article"."InformationArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."InformationArticle" IS 'Description et caractéristiques complémentaires du produit, distinctes des observations.';

--
-- Name: COLUMN "V_Article"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';

--
-- Name: COLUMN "V_Article"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_Article"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_Article"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Article"."StockPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."StockPerime" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : StockPerime.';

--
-- Name: COLUMN "V_Article"."StockProchePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."StockProchePeremption" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : StockProchePeremption.';

--
-- Name: COLUMN "V_Article"."StockSansDatePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."StockSansDatePeremption" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : StockSansDatePeremption.';

--
-- Name: COLUMN "V_Article"."DateProchainePeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."DateProchainePeremption" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : DateProchainePeremption.';

--
-- Name: COLUMN "V_Article"."LotsPerimes"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."LotsPerimes" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : LotsPerimes.';

--
-- Name: COLUMN "V_Article"."LotsProchesPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."LotsProchesPeremption" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : LotsProchesPeremption.';

--
-- Name: COLUMN "V_Article"."SeuilAlerteJours"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."SeuilAlerteJours" IS 'Conservation exhaustive du stock restant par lot et du stock sans lot : SeuilAlerteJours.';

--
-- Name: COLUMN "V_Article"."VisibleCatalogue"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Article"."VisibleCatalogue" IS 'Choix de publication du catalogue partagé porté par l’article ; affichable et modifiable selon les droits du propriétaire. Les autres colonnes de gestion conservent leur contrat et leur ordre.';

--
-- Name: V_AlertStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_AlertStock" AS
 SELECT source."ID_Article",
    source."CodeArticleInterne",
    source."NomArticle",
    source."AbrUnite",
    source."QteArticle",
    source."QteMinArticle",
    source."QteACommander",
    source."Marge",
    source."EtatStock",
    source."EstRupture",
    source."EstAlerteStock",
    source."PrioriteStock",
    source."EtatPeremption",
    source."JoursAvantPeremption",
    source."EstPerime",
    source."EstAlertePeremption",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk"
   FROM (( SELECT historique."ID_Article",
            historique."CodeArticleInterne",
            historique."NomArticle",
            historique."AbrUnite",
            historique."QteArticle",
            historique."QteMinArticle",
            historique."QteACommander",
            historique."Marge",
            historique."EtatStock",
            historique."EstRupture",
            historique."EstAlerteStock",
            historique."PrioriteStock",
            historique."EtatPeremption",
            historique."JoursAvantPeremption",
            historique."EstPerime",
            historique."EstAlertePeremption",
            source_1."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( SELECT a."ID_Article",
                    a."CodeArticleInterne",
                    a."NomArticle",
                    a."AbrUnite",
                    a."QteArticle",
                    a."QteMinArticle",
                    a."QteACommander",
                    ((COALESCE(a."QteArticle", (0)::numeric) - COALESCE(a."QteMinArticle", (0)::numeric)))::numeric(14,3) AS "Marge",
                    a."EtatStock",
                    a."EstRupture",
                    a."EstAlerteStock",
                    a."PrioriteStock",
                    a."EtatPeremption",
                    a."JoursAvantPeremption",
                    a."EstPerime",
                    a."EstAlertePeremption"
                   FROM logistique."V_Article" a
                  WHERE ((a."EstRupture" = true) OR (a."EstAlerteStock" = true))) historique
             LEFT JOIN logistique."T_Article" source_1 ON ((source_1."ID_Article" = historique."ID_Article")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Article" r ON ((r."ID_Article" = source."ID_Article")));

--
-- Name: VIEW "V_AlertStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_AlertStock" IS 'Articles en rupture ou au seuil minimal depuis V_Article, au grain article. Les ruptures sont incluses même sans seuil renseigné ; les autres alertes exigent le seuil défini dans V_Article. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';

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
-- Name: COLUMN "V_AlertStock"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';

--
-- Name: COLUMN "V_AlertStock"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_AlertStock"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_AlertStock"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AlertStock"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: V_AuditStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_AuditStock" AS
 SELECT source."ID_Article",
    source."CodeArticleInterne",
    source."NomArticle",
    source."StockArticle",
    source."StockMouvements",
    source."Ecart",
    source."N_Mouvements",
    source."QteEntree",
    source."QteSortie",
    source."EstStockCoherent",
    source."EtatAuditStock",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk"
   FROM (( SELECT historique."ID_Article",
            historique."CodeArticleInterne",
            historique."NomArticle",
            historique."StockArticle",
            historique."StockMouvements",
            historique."Ecart",
            historique."N_Mouvements",
            historique."QteEntree",
            historique."QteSortie",
            historique."EstStockCoherent",
            historique."EtatAuditStock",
            source_1."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( SELECT fn_audit_stock."ID_Article",
                    fn_audit_stock."CodeArticleInterne",
                    fn_audit_stock."NomArticle",
                    fn_audit_stock."StockArticle",
                    fn_audit_stock."StockMouvements",
                    fn_audit_stock."Ecart",
                    fn_audit_stock."N_Mouvements",
                    fn_audit_stock."QteEntree",
                    fn_audit_stock."QteSortie",
                    (fn_audit_stock."Ecart" = (0)::numeric) AS "EstStockCoherent",
                        CASE
                            WHEN (fn_audit_stock."Ecart" = (0)::numeric) THEN 'Cohérent'::text
                            WHEN (fn_audit_stock."Ecart" > (0)::numeric) THEN 'Stock article supérieur aux mouvements'::text
                            ELSE 'Stock article inférieur aux mouvements'::text
                        END AS "EtatAuditStock"
                   FROM logistique.fn_audit_stock(NULL::integer, NULL::timestamp without time zone) fn_audit_stock("ID_Article", "CodeArticleInterne", "NomArticle", "StockArticle", "StockMouvements", "Ecart", "N_Mouvements", "QteEntree", "QteSortie")) historique
             LEFT JOIN logistique."T_Article" source_1 ON ((source_1."ID_Article" = historique."ID_Article")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Article" r ON ((r."ID_Article" = source."ID_Article")));

--
-- Name: VIEW "V_AuditStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_AuditStock" IS 'Audit courant au grain article depuis fn_audit_stock(NULL,NULL) : stock enregistré, somme des mouvements signés, écart, entrées/sorties et état de cohérence. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';

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
-- Name: COLUMN "V_AuditStock"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';

--
-- Name: COLUMN "V_AuditStock"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_AuditStock"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_AuditStock"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: V_MouvementStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_MouvementStock" AS
 SELECT source."ID_Mvt",
    source."ID_ArticleFk",
    source."CodeArticleInterne",
    source."NomArticle",
    source."ID_cmdFk",
    source."CodeCmd",
    source."DateCmd",
    source."ID_TypeCmdActuel",
    source."DateHeureAutoMvt",
    source."DateMvt",
    source."ID_TypeMvt",
    source."AbrTypeMvt",
    source."TypeMvt",
    source."QteMvt",
    source."PUMvt",
    source."SigneStock",
    source."QteMvtSigned",
    source."MontantMvt",
    source."MontantMvtSigned",
    source."OrigineMouvement",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk",
    r."ID_TiersFk",
    t."Nom" AS "TiersNom"
   FROM ((( SELECT historique."ID_Mvt",
            historique."ID_ArticleFk",
            historique."CodeArticleInterne",
            historique."NomArticle",
            historique."ID_cmdFk",
            historique."CodeCmd",
            historique."DateCmd",
            historique."ID_TypeCmdActuel",
            historique."DateHeureAutoMvt",
            historique."DateMvt",
            historique."ID_TypeMvt",
            historique."AbrTypeMvt",
            historique."TypeMvt",
            historique."QteMvt",
            historique."PUMvt",
            historique."SigneStock",
            historique."QteMvtSigned",
            historique."MontantMvt",
            historique."MontantMvtSigned",
            historique."OrigineMouvement",
            source_1."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( SELECT m."ID_Mvt",
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
                    COALESCE(m."QteMvt", (0)::numeric) AS "QteMvt",
                    (COALESCE(m."PUMvt", (0)::numeric))::numeric(12,2) AS "PUMvt",
                    COALESCE((logistique.fn_effet_type_bon(m."ID_TypeMvtFk"))::integer, 0) AS "SigneStock",
                    (COALESCE(m."QteMvt", (0)::numeric) * (COALESCE((logistique.fn_effet_type_bon(m."ID_TypeMvtFk"))::integer, 0))::numeric) AS "QteMvtSigned",
                    ((COALESCE(m."QteMvt", (0)::numeric) * COALESCE(m."PUMvt", (0)::numeric)))::numeric(14,2) AS "MontantMvt",
                    (((COALESCE(m."QteMvt", (0)::numeric) * COALESCE(m."PUMvt", (0)::numeric)) * (COALESCE((logistique.fn_effet_type_bon(m."ID_TypeMvtFk"))::integer, 0))::numeric))::numeric(14,2) AS "MontantMvtSigned",
                        CASE
                            WHEN (m."ID_cmdFk" IS NULL) THEN 'Ajustement direct article'::text
                            ELSE 'Commande'::text
                        END AS "OrigineMouvement"
                   FROM (((logistique."T_Mouvement" m
                     LEFT JOIN logistique."T_Article" a ON ((a."ID_Article" = m."ID_ArticleFk")))
                     LEFT JOIN logistique."T_Commande" c ON ((c."ID_Commande" = m."ID_cmdFk")))
                     LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = m."ID_TypeMvtFk")))) historique
             LEFT JOIN logistique."T_Mouvement" source_1 ON ((source_1."ID_Mvt" = historique."ID_Mvt")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source."ID_cmdFk")))
     LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")));

--
-- Name: VIEW "V_MouvementStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_MouvementStock" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves. Le signe de stock est celui du type historique, calcule par fn_effet_type_bon, jamais par la categorie actuelle.';

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

COMMENT ON COLUMN logistique."V_MouvementStock"."AbrTypeMvt" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_MouvementStock"."TypeMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."TypeMvt" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

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

COMMENT ON COLUMN logistique."V_MouvementStock"."SigneStock" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

--
-- Name: COLUMN "V_MouvementStock"."QteMvtSigned"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."QteMvtSigned" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

--
-- Name: COLUMN "V_MouvementStock"."MontantMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."MontantMvt" IS 'Quantité × prix unitaire historique du mouvement. Expression projetée : (COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric))::numeric(14,2) AS "MontantMvt".';

--
-- Name: COLUMN "V_MouvementStock"."MontantMvtSigned"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."MontantMvtSigned" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

--
-- Name: COLUMN "V_MouvementStock"."OrigineMouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."OrigineMouvement" IS 'Commande si ID_cmdFk est renseigné, sinon Ajustement direct article. Expression projetée : CASE WHEN m."ID_cmdFk" IS NULL THEN ''Ajustement direct article''::text ELSE ''Commande''::text END AS "OrigineMouvement".';

--
-- Name: COLUMN "V_MouvementStock"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."ID_DeviseFk" IS 'Référence de devise du mouvement historique ; aucune conversion.';

--
-- Name: COLUMN "V_MouvementStock"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_MouvementStock"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_MouvementStock"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_MouvementStock"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."ID_TiersFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_MouvementStock"."TiersNom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementStock"."TiersNom" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: V_AuditStock_Theorique; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_AuditStock_Theorique" AS
 SELECT historique."ID_Article",
    historique."CodeArticleInterne",
    historique."NomArticle",
    historique."StockEnregistre",
    historique."StockCalcule",
    historique."Ecart",
    historique."EstStockCoherent",
    source."ID_DeviseFk",
    logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
    (devise."NomGenerique")::text AS "DeviseLibelle"
   FROM ((( WITH mvt AS (
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
             LEFT JOIN mvt ON ((mvt."ID_ArticleFk" = a."ID_Article")))) historique
     LEFT JOIN logistique."T_Article" source ON ((source."ID_Article" = historique."ID_Article")))
     LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source."ID_DeviseFk")));

--
-- Name: VIEW "V_AuditStock_Theorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_AuditStock_Theorique" IS 'Rapprochement au grain article entre QteArticle courant et somme de V_MouvementStock.QteMvtSigned ; écart = stock enregistré moins stock calculé. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';

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
-- Name: COLUMN "V_AuditStock_Theorique"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';

--
-- Name: COLUMN "V_AuditStock_Theorique"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_AuditStock_Theorique"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: V_Avoir; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Avoir" AS
 SELECT v."ID_Avoir",
    v."ID_FactureFk",
    v."ID_CommandeFk",
    v."IdEntiteFk",
    v."ID_UserFk",
    v."CodeAvoir",
    v."DateAvoir",
    v."Motif",
    v."ID_DeviseFk",
    v."DeviseCode",
    v."MontantTTC",
    v."RequestId",
    v."PayloadHash",
    v."TransactionCreation",
    v."CreeLe",
    v."MontantImpute",
    v."MontantRembourse",
    v."Disponible",
    a."TauxTVA",
    a."MontantHT",
    a."MontantTVA"
   FROM (( SELECT a_1."ID_Avoir",
            a_1."ID_FactureFk",
            a_1."ID_CommandeFk",
            a_1."IdEntiteFk",
            a_1."ID_UserFk",
            a_1."CodeAvoir",
            a_1."DateAvoir",
            a_1."Motif",
            a_1."ID_DeviseFk",
            a_1."DeviseCode",
            a_1."MontantTTC",
            a_1."RequestId",
            a_1."PayloadHash",
            a_1."TransactionCreation",
            a_1."CreeLe",
            (COALESCE(s.impute, (0)::numeric))::numeric(12,2) AS "MontantImpute",
            (COALESCE(r.rembourse, (0)::numeric))::numeric(12,2) AS "MontantRembourse",
            (((a_1."MontantTTC" - COALESCE(s.impute, (0)::numeric)) - COALESCE(r.rembourse, (0)::numeric)))::numeric(12,2) AS "Disponible"
           FROM ((logistique."T_Avoir" a_1
             LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS impute
                   FROM logistique."T_AvoirAffectation"
                  WHERE ("T_AvoirAffectation"."ID_AvoirFk" = a_1."ID_Avoir")) s ON (true))
             LEFT JOIN LATERAL ( SELECT sum("T_Remboursement"."Montant") AS rembourse
                   FROM logistique."T_Remboursement"
                  WHERE ("T_Remboursement"."ID_AvoirFk" = a_1."ID_Avoir")) r ON (true))) v
     JOIN logistique."T_Avoir" a ON ((a."ID_Avoir" = v."ID_Avoir")));

--
-- Name: VIEW "V_Avoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Avoir" IS 'Avoir historique HT/TVA/TTC et disponible après imputations et remboursements ; sans réécriture de sa facture ni mouvement de stock.';

--
-- Name: COLUMN "V_Avoir"."ID_Avoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."ID_Avoir" IS 'Identifiant interne et stable de l’avoir émis.';

--
-- Name: COLUMN "V_Avoir"."ID_FactureFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."ID_FactureFk" IS 'Facture originale et immuable à laquelle se rapporte l’avoir.';

--
-- Name: COLUMN "V_Avoir"."ID_CommandeFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."ID_CommandeFk" IS 'Bon original facturé dont les articles ont été retournés.';

--
-- Name: COLUMN "V_Avoir"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."IdEntiteFk" IS 'Entreprise propriétaire durable de l’avoir et de sa facture.';

--
-- Name: COLUMN "V_Avoir"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."ID_UserFk" IS 'Auteur réel de l’émission, imputation ou remboursement.';

--
-- Name: COLUMN "V_Avoir"."CodeAvoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."CodeAvoir" IS 'Référence automatique et immuable avr-identifiant.';

--
-- Name: COLUMN "V_Avoir"."DateAvoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."DateAvoir" IS 'Date et heure effectives de l’émission de l’avoir.';

--
-- Name: COLUMN "V_Avoir"."Motif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."Motif" IS 'Justification métier de l’avoir après retour facturé.';

--
-- Name: COLUMN "V_Avoir"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."ID_DeviseFk" IS 'Devise de la facture d’origine, issue du référentiel.';

--
-- Name: COLUMN "V_Avoir"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."DeviseCode" IS 'Code de la devise de la facture, conservé à l’émission.';

--
-- Name: COLUMN "V_Avoir"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."MontantTTC" IS 'Montant émis égal à la somme des lignes.';

--
-- Name: COLUMN "V_Avoir"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."RequestId" IS 'Identifiant unique du traitement empêchant les doubles envois.';

--
-- Name: COLUMN "V_Avoir"."PayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."PayloadHash" IS 'Empreinte canonique à comparer lors du rejeu d’une demande.';

--
-- Name: COLUMN "V_Avoir"."TransactionCreation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."TransactionCreation" IS 'Transaction autorisée à insérer les lignes du nouvel avoir.';

--
-- Name: COLUMN "V_Avoir"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."CreeLe" IS 'Horodatage serveur de l’enregistrement.';

--
-- Name: COLUMN "V_Avoir"."MontantImpute"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."MontantImpute" IS 'Cumul des imputations sur des factures autorisées.';

--
-- Name: COLUMN "V_Avoir"."MontantRembourse"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."MontantRembourse" IS 'Cumul des remboursements effectivement enregistrés.';

--
-- Name: COLUMN "V_Avoir"."Disponible"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."Disponible" IS 'Montant émis non encore imputé ni remboursé.';

--
-- Name: COLUMN "V_Avoir"."TauxTVA"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."TauxTVA" IS 'Taux historique de la facture créditée.';

--
-- Name: COLUMN "V_Avoir"."MontantHT"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."MontantHT" IS 'Montant HT restitué par cet avoir.';

--
-- Name: COLUMN "V_Avoir"."MontantTVA"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Avoir"."MontantTVA" IS 'Taxe historique restituée par cet avoir.';

--
-- Name: V_BonInventaire; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_BonInventaire" AS
 SELECT DISTINCT "T_InventaireLigne"."ID_CommandeCorrectionFk" AS "ID_Commande",
    "T_InventaireLigne"."ID_InventaireFk" AS "ID_Inventaire",
    'correction'::text AS "RoleBon"
   FROM logistique."T_InventaireLigne"
  WHERE ("T_InventaireLigne"."ID_CommandeCorrectionFk" IS NOT NULL)
UNION
 SELECT DISTINCT "T_InventaireLigne"."ID_CommandeAnnulationFk" AS "ID_Commande",
    "T_InventaireLigne"."ID_InventaireFk" AS "ID_Inventaire",
    'annulation'::text AS "RoleBon"
   FROM logistique."T_InventaireLigne"
  WHERE ("T_InventaireLigne"."ID_CommandeAnnulationFk" IS NOT NULL);

--
-- Name: VIEW "V_BonInventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_BonInventaire" IS 'Bons correcteurs et compensateurs rattachés aux comptages ; flux physiques internes sans facturation ni retour commercial.';

--
-- Name: COLUMN "V_BonInventaire"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_BonInventaire"."ID_Commande" IS 'Identité du bon de stock interne ; un bon peut regrouper plusieurs articles comptés.';

--
-- Name: COLUMN "V_BonInventaire"."ID_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_BonInventaire"."ID_Inventaire" IS 'Comptage physique à l’origine du bon ou de sa compensation.';

--
-- Name: COLUMN "V_BonInventaire"."RoleBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_BonInventaire"."RoleBon" IS 'Correction du comptage ou compensation d’une annulation ; ne désigne pas une vente ou un retour client.';

--
-- Name: V_CategorieDossierSuivi; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CategorieDossierSuivi" AS
 SELECT "ID_CategorieDossierSuivi",
    "ID_UserFk",
    "IdEntiteFk",
    "Nom",
    "Couleur",
    "Actif",
    "CreeLe",
    "ModifieLe"
   FROM logistique."T_CategorieDossierSuivi";

--
-- Name: VIEW "V_CategorieDossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CategorieDossierSuivi" IS 'Projection de lecture du classement des articles, à filtrer par propriétaire et organisation.';

--
-- Name: COLUMN "V_CategorieDossierSuivi"."ID_CategorieDossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."ID_CategorieDossierSuivi" IS 'Identifiant permanent de la catégorie de dossiers.';

--
-- Name: COLUMN "V_CategorieDossierSuivi"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';

--
-- Name: COLUMN "V_CategorieDossierSuivi"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_CategorieDossierSuivi"."Nom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."Nom" IS 'Libellé métier du dossier ou de sa catégorie.';

--
-- Name: COLUMN "V_CategorieDossierSuivi"."Couleur"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';

--
-- Name: COLUMN "V_CategorieDossierSuivi"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."Actif" IS 'État actif ; false conserve le classement archivé.';

--
-- Name: COLUMN "V_CategorieDossierSuivi"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."CreeLe" IS 'Instant de création.';

--
-- Name: COLUMN "V_CategorieDossierSuivi"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';

--
-- Name: V_Client; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Client" AS
 SELECT t."ID_Client",
    t."IdEntiteFk",
    t."Nature",
    t."ID_TypeClientFk",
    t."Nom",
    t."Email",
    t."Telephone",
    t."Adresse",
    t."IdUserFk",
    t."IdProfessionnelFk",
    t."IdEntiteRepresenteeFk",
    t."ObsClient",
    t."Actif",
    t."CreeParUserFk",
    t."ModifieParUserFk",
    t."DateCreation",
    t."DateModification",
    g."NomGenerique" AS "TypeClient",
    e."NomEntite" AS "Entreprise",
    e."NomEntite",
    concat_ws(' '::text, u."PrenomUser", u."NomUser") AS "NomUtilisateur",
    concat_ws(' '::text, pu."PrenomUser", pu."NomUser") AS "NomProfessionnel",
    rep."NomEntite" AS "NomEntiteRepresentee"
   FROM ((((((logistique."T_Client" t
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = t."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = t."ID_TypeClientFk")))
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = t."IdUserFk")))
     LEFT JOIN professionnel."T_Professionnel" p ON ((p."IdProfessionnel" = t."IdProfessionnelFk")))
     LEFT JOIN systeme."T_Utilisateurs" pu ON ((pu."IdUser" = p."IdUserFk")))
     LEFT JOIN systeme."T_Entite" rep ON ((rep."IdEntite" = t."IdEntiteRepresenteeFk")));

--
-- Name: VIEW "V_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Client" IS 'Fiche commune de tiers avec catégorie et entreprise propriétaire ; filtrage serveur obligatoire.';

--
-- Name: COLUMN "V_Client"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Client"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Client"."TypeClient"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Client"."TypeClient" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: V_Facture; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Facture" AS
 SELECT v."ID_Facture",
    v."ID_CommandeFk",
    v."CodeFacture",
    v."ID_UserFk",
    v."IdEntiteFk",
    v."RequestId",
    v."PayloadHash",
    v."DateFacture",
    v."DateEcheancePaiement",
    v."ID_ModePaiementFk",
    v."ID_ConditionPaiementFk",
    v."DelaiJours",
    v."ID_DeviseFk",
    v."DeviseCode",
    v."DeviseLibelle",
    v."MontantHT",
    v."MontantTTC",
    v."TransactionCreation",
    v."CreeLe",
    v."ModifieLe",
    v."MontantFacture",
    v."TotalRegle",
    v."Reste",
    v."NbReglements",
    v."DernierReglement",
    v."EtatReglement",
    v."EstEnRetard",
    v."JoursAvantEcheance",
    v."MontantAvoirAEtablir",
    v."AvoirAEtablir",
    v."AvoirImpute",
    v."MontantNetARegler",
    f."TauxTVA",
    f."MontantTVA"
   FROM (( SELECT b."ID_Facture",
            b."ID_CommandeFk",
            b."CodeFacture",
            b."ID_UserFk",
            b."IdEntiteFk",
            b."RequestId",
            b."PayloadHash",
            b."DateFacture",
            b."DateEcheancePaiement",
            b."ID_ModePaiementFk",
            b."ID_ConditionPaiementFk",
            b."DelaiJours",
            b."ID_DeviseFk",
            b."DeviseCode",
            b."DeviseLibelle",
            b."MontantHT",
            b."MontantTTC",
            b."TransactionCreation",
            b."CreeLe",
            b."ModifieLe",
            b."MontantFacture",
            b."TotalRegle",
            ((b."Reste" - COALESCE(cr.total, (0)::numeric)))::numeric(12,2) AS "Reste",
            b."NbReglements",
            b."DernierReglement",
                CASE
                    WHEN ((b."Reste" - COALESCE(cr.total, (0)::numeric)) <= (0)::numeric) THEN 'Réglée'::text
                    WHEN ((b."TotalRegle" > (0)::numeric) OR (COALESCE(cr.total, (0)::numeric) > (0)::numeric)) THEN 'Partiellement réglée'::text
                    ELSE 'Non réglée'::text
                END AS "EtatReglement",
            (b."EstEnRetard" AND ((b."Reste" - COALESCE(cr.total, (0)::numeric)) > (0)::numeric)) AS "EstEnRetard",
            b."JoursAvantEcheance",
            (logistique.fn_montant_avoir_attente(b."ID_CommandeFk"))::numeric(12,2) AS "MontantAvoirAEtablir",
            (logistique.fn_montant_avoir_attente(b."ID_CommandeFk") > (0)::numeric) AS "AvoirAEtablir",
            (COALESCE(cr.total, (0)::numeric))::numeric(12,2) AS "AvoirImpute",
            ((b."MontantTTC" - COALESCE(cr.total, (0)::numeric)))::numeric(12,2) AS "MontantNetARegler"
           FROM (( WITH payments AS (
                         SELECT "T_Reglements"."CodeFactureFk",
                            (COALESCE(sum("T_Reglements"."MontantRegle"), (0)::numeric))::numeric(12,2) AS total,
                            count(*) AS n,
                            max("T_Reglements"."DateReglement") AS last
                           FROM logistique."T_Reglements"
                          GROUP BY "T_Reglements"."CodeFactureFk"
                        ), returned AS (
                         SELECT r."ID_CommandeOrigineFk" AS command_id,
                            d."ID_ArticleFk",
                            sum(d."QteCmdDetail") AS quantity
                           FROM (logistique."T_RetourBon" r
                             JOIN logistique."T_CommandeDetail" d ON ((d."ID_CmdFk" = r."ID_CommandeRetourFk")))
                          GROUP BY r."ID_CommandeOrigineFk", d."ID_ArticleFk"
                        ), credit AS (
                         SELECT l."ID_FactureFk",
                            (sum((GREATEST((COALESCE(r.quantity, (0)::numeric) - (l."QteRetourAvantFacture")::numeric), (0)::numeric) * l."PUFacture")))::numeric(12,2) AS total
                           FROM (logistique."T_FactureLigne" l
                             LEFT JOIN returned r ON (((r.command_id = l."ID_CmdFk") AND (r."ID_ArticleFk" = l."ID_ArticleFk"))))
                          GROUP BY l."ID_FactureFk"
                        )
                 SELECT f_1."ID_Facture",
                    f_1."ID_CommandeFk",
                    f_1."CodeFacture",
                    f_1."ID_UserFk",
                    f_1."IdEntiteFk",
                    f_1."RequestId",
                    f_1."PayloadHash",
                    f_1."DateFacture",
                    f_1."DateEcheancePaiement",
                    f_1."ID_ModePaiementFk",
                    f_1."ID_ConditionPaiementFk",
                    f_1."DelaiJours",
                    f_1."ID_DeviseFk",
                    f_1."DeviseCode",
                    f_1."DeviseLibelle",
                    f_1."MontantHT",
                    f_1."MontantTTC",
                    f_1."TransactionCreation",
                    f_1."CreeLe",
                    f_1."ModifieLe",
                    f_1."MontantTTC" AS "MontantFacture",
                    (COALESCE(p.total, (0)::numeric))::numeric(12,2) AS "TotalRegle",
                    ((f_1."MontantTTC" - COALESCE(p.total, (0)::numeric)))::numeric(12,2) AS "Reste",
                    COALESCE(p.n, (0)::bigint) AS "NbReglements",
                    p.last AS "DernierReglement",
                        CASE
                            WHEN (COALESCE(p.total, (0)::numeric) <= (0)::numeric) THEN 'Non réglée'::text
                            WHEN (p.total < f_1."MontantTTC") THEN 'Partiellement réglée'::text
                            ELSE 'Réglée'::text
                        END AS "EtatReglement",
                    (((f_1."DateEcheancePaiement")::date < CURRENT_DATE) AND (f_1."MontantTTC" > COALESCE(p.total, (0)::numeric))) AS "EstEnRetard",
                    ((f_1."DateEcheancePaiement")::date - CURRENT_DATE) AS "JoursAvantEcheance",
                    (COALESCE(c.total, (0)::numeric))::numeric(12,2) AS "MontantAvoirAEtablir",
                    (COALESCE(c.total, (0)::numeric) > (0)::numeric) AS "AvoirAEtablir"
                   FROM ((logistique."T_Facture" f_1
                     LEFT JOIN payments p ON (((p."CodeFactureFk")::text = (f_1."CodeFacture")::text)))
                     LEFT JOIN credit c ON ((c."ID_FactureFk" = f_1."ID_Facture")))) b
             LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS total
                   FROM logistique."T_AvoirAffectation"
                  WHERE ("T_AvoirAffectation"."ID_CommandeCibleFk" = b."ID_CommandeFk")) cr ON (true))) v
     JOIN logistique."T_Facture" f ON ((f."ID_Facture" = v."ID_Facture")));

--
-- Name: VIEW "V_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Facture" IS 'Facture figée, taxe historique, règlements, imputations et solde net ; une modification du taux d’entreprise ne modifie aucun montant émis.';

--
-- Name: COLUMN "V_Facture"."ID_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."ID_Facture" IS 'Projection financière : ID_Facture ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."ID_CommandeFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."ID_CommandeFk" IS 'Projection financière : ID_CommandeFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."CodeFacture" IS 'Projection financière : CodeFacture ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."ID_UserFk" IS 'Projection financière : ID_UserFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Facture"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."RequestId" IS 'Projection financière : RequestId ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."PayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."PayloadHash" IS 'Projection financière : PayloadHash ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."DateFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."DateFacture" IS 'Projection financière : DateFacture ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."DateEcheancePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."DateEcheancePaiement" IS 'Projection financière : DateEcheancePaiement ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."ID_ModePaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."ID_ModePaiementFk" IS 'Projection financière : ID_ModePaiementFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."ID_ConditionPaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."ID_ConditionPaiementFk" IS 'Projection financière : ID_ConditionPaiementFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."DelaiJours"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."DelaiJours" IS 'Projection financière : DelaiJours ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."ID_DeviseFk" IS 'Projection financière : ID_DeviseFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."DeviseCode" IS 'Projection financière : DeviseCode ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."DeviseLibelle" IS 'Projection financière : DeviseLibelle ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."MontantHT"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."MontantHT" IS 'Projection financière : MontantHT ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."MontantTTC" IS 'Projection financière : MontantTTC ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."TransactionCreation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."TransactionCreation" IS 'Projection financière : TransactionCreation ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."CreeLe" IS 'Projection financière : CreeLe ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."ModifieLe" IS 'Projection financière : ModifieLe ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."MontantFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."MontantFacture" IS 'Projection financière : MontantFacture ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."TotalRegle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."TotalRegle" IS 'Projection financière : TotalRegle ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."Reste"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."Reste" IS 'Solde unique de référence : montant émis diminué des encaissements et des avoirs imputés.';

--
-- Name: COLUMN "V_Facture"."NbReglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."NbReglements" IS 'Projection financière : NbReglements ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."DernierReglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."DernierReglement" IS 'Projection financière : DernierReglement ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."EtatReglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."EtatReglement" IS 'Projection financière : EtatReglement ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."EstEnRetard"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."EstEnRetard" IS 'Projection financière : EstEnRetard ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."JoursAvantEcheance"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."JoursAvantEcheance" IS 'Projection financière : JoursAvantEcheance ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."MontantAvoirAEtablir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."MontantAvoirAEtablir" IS 'Projection financière : MontantAvoirAEtablir ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."AvoirAEtablir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."AvoirAEtablir" IS 'Projection financière : AvoirAEtablir ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_Facture"."AvoirImpute"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."AvoirImpute" IS 'Imputations d’avoirs distinctes des encaissements.';

--
-- Name: COLUMN "V_Facture"."MontantNetARegler"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."MontantNetARegler" IS 'Montant émis diminué des imputations avant encaissements.';

--
-- Name: COLUMN "V_Facture"."TauxTVA"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."TauxTVA" IS 'Taux figé à l’émission de la facture.';

--
-- Name: COLUMN "V_Facture"."MontantTVA"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Facture"."MontantTVA" IS 'Somme figée des taxes arrondies de lignes.';

--
-- Name: V_Commande; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Commande" AS
 SELECT v."ID_Commande",
    v."ID_TypeCmdFk",
    v."ID_StatutCmdFk",
    v."ID_ClientFk",
    v."ID_UserFk",
    v."geolocalisationCmd",
    v."DateHeureAutoCmd",
    v."DateCmd",
    v."CodeCmd",
    v."RefCmd",
    v."MontantHT",
    v."MontantTTC",
    v."UrlBL",
    v."ObsCmd",
    v."SelectCmd",
    v."DateHeureAutoFacture",
    v."DateFacture",
    v."CodeFacture",
    v."MontantRegleFacture",
    v."MontantResteFacture",
    v."StatusFacture",
    v."ValideRemiseFacture",
    v."UrlFacture",
    v."ID_ConditionPaiementFk",
    v."DateEcheancePaiement",
    v."ID_ModePaiementFk",
    v."NomClientSaisi",
    v."AbrTypeCmd",
    v."TypeCmd",
    v."SigneCommande",
    v."EstCommandeEntree",
    v."EstCommandeSortie",
    v."AbrStatutCmd",
    v."StatutCmd",
    v."NomUser",
    v."PrenomUser",
    v."NomComplet",
    v."AbrConditionPaiement",
    v."ConditionPaiement",
    v."AbrModePaiement",
    v."ModePaiement",
    v."MontantHTCalc",
    v."MontantTTCCalc",
    v."MontantRegleFactureCalc",
    v."MontantResteFactureCalc",
    v."TotalRegleReel",
    v."ResteReel",
    v."NbReglements",
    v."DernierReglement",
    v."EtatPaiement",
    v."EstPaiementEnRetard",
    v."JoursAvantEcheance",
    v."NbLignes",
    v."NbArticlesDistincts",
    v."QteTotale",
    v."MontantDetails",
    v."ListeArticles",
    v."EstCommandeSansDetails",
    v."EcartMontantDetails",
    v."EstMontantIncoherent",
    v."EtatControleCommande",
    v."ID_DeviseFk",
    v."DeviseCode",
    v."DeviseLibelle",
    v."ID_Facture",
    v."EstFactureSnapshot",
    v."MontantFacture",
    v."MontantAvoirAEtablir",
    v."AvoirAEtablir",
    v."IdEntiteFk",
    v."ID_TiersFk",
    v."TiersNom",
    v."ID_DestinationFk",
    v."DestinationLibelle",
    v."AvoirImpute",
    v."OrigineBon",
    v."ID_ArticleInitialFk",
    v."NatureBon",
    v."AncienCodeCmd",
    v."RenumeroteLe",
    f."TauxTVA" AS "TauxTVAFacture",
    f."MontantTVA" AS "MontantTVAFacture",
    f."MontantHT" AS "MontantHTFacture"
   FROM (( SELECT source."ID_Commande",
            source."ID_TypeCmdFk",
            source."ID_StatutCmdFk",
            source."ID_ClientFk",
            source."ID_UserFk",
            source."geolocalisationCmd",
            source."DateHeureAutoCmd",
            source."DateCmd",
            source."CodeCmd",
            source."RefCmd",
            source."MontantHT",
            source."MontantTTC",
            source."UrlBL",
            source."ObsCmd",
            source."SelectCmd",
            source."DateHeureAutoFacture",
            source."DateFacture",
            source."CodeFacture",
            source."MontantRegleFacture",
            source."MontantResteFacture",
            source."StatusFacture",
            source."ValideRemiseFacture",
            source."UrlFacture",
            source."ID_ConditionPaiementFk",
            source."DateEcheancePaiement",
            source."ID_ModePaiementFk",
            source."NomClientSaisi",
            source."AbrTypeCmd",
            source."TypeCmd",
            source."SigneCommande",
            source."EstCommandeEntree",
            source."EstCommandeSortie",
            source."AbrStatutCmd",
            source."StatutCmd",
            source."NomUser",
            source."PrenomUser",
            source."NomComplet",
            source."AbrConditionPaiement",
            source."ConditionPaiement",
            source."AbrModePaiement",
            source."ModePaiement",
            source."MontantHTCalc",
            source."MontantTTCCalc",
            source."MontantRegleFactureCalc",
            source."MontantResteFactureCalc",
            source."TotalRegleReel",
            source."ResteReel",
            source."NbReglements",
            source."DernierReglement",
            source."EtatPaiement",
            source."EstPaiementEnRetard",
            source."JoursAvantEcheance",
            source."NbLignes",
            source."NbArticlesDistincts",
            source."QteTotale",
            source."MontantDetails",
            source."ListeArticles",
            source."EstCommandeSansDetails",
            source."EcartMontantDetails",
            source."EstMontantIncoherent",
            source."EtatControleCommande",
            source."ID_DeviseFk",
            source."DeviseCode",
            source."DeviseLibelle",
            source."ID_Facture",
            source."EstFactureSnapshot",
            source."MontantFacture",
            source."MontantAvoirAEtablir",
            source."AvoirAEtablir",
            source."IdEntiteFk",
            source."ID_TiersFk",
            source."TiersNom",
            source."ID_DestinationFk",
            source."DestinationLibelle",
            source."AvoirImpute",
            source."OrigineBon",
            source."ID_ArticleInitialFk",
            source."NatureBon",
            h."AncienCodeCmd",
            h."RenumeroteLe"
           FROM (( SELECT source_1."ID_Commande",
                    source_1."ID_TypeCmdFk",
                    source_1."ID_StatutCmdFk",
                    source_1."ID_ClientFk",
                    source_1."ID_UserFk",
                    source_1."geolocalisationCmd",
                    source_1."DateHeureAutoCmd",
                    source_1."DateCmd",
                    source_1."CodeCmd",
                    source_1."RefCmd",
                    source_1."MontantHT",
                    source_1."MontantTTC",
                    source_1."UrlBL",
                    source_1."ObsCmd",
                    source_1."SelectCmd",
                    source_1."DateHeureAutoFacture",
                    source_1."DateFacture",
                    source_1."CodeFacture",
                    source_1."MontantRegleFacture",
                    source_1."MontantResteFacture",
                    source_1."StatusFacture",
                    source_1."ValideRemiseFacture",
                    source_1."UrlFacture",
                    source_1."ID_ConditionPaiementFk",
                    source_1."DateEcheancePaiement",
                    source_1."ID_ModePaiementFk",
                    source_1."NomClientSaisi",
                    source_1."AbrTypeCmd",
                    source_1."TypeCmd",
                    source_1."SigneCommande",
                    source_1."EstCommandeEntree",
                    source_1."EstCommandeSortie",
                    source_1."AbrStatutCmd",
                    source_1."StatutCmd",
                    source_1."NomUser",
                    source_1."PrenomUser",
                    source_1."NomComplet",
                    source_1."AbrConditionPaiement",
                    source_1."ConditionPaiement",
                    source_1."AbrModePaiement",
                    source_1."ModePaiement",
                    source_1."MontantHTCalc",
                    source_1."MontantTTCCalc",
                    (
                        CASE
                            WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                            ELSE source_1."MontantRegleFactureCalc"
                        END)::numeric(12,2) AS "MontantRegleFactureCalc",
                    (
                        CASE
                            WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                            ELSE source_1."MontantResteFactureCalc"
                        END)::numeric(12,2) AS "MontantResteFactureCalc",
                    (
                        CASE
                            WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                            ELSE source_1."TotalRegleReel"
                        END)::numeric(12,2) AS "TotalRegleReel",
                    (
                        CASE
                            WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                            ELSE source_1."ResteReel"
                        END)::numeric(12,2) AS "ResteReel",
                    source_1."NbReglements",
                    source_1."DernierReglement",
                        CASE
                            WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN 'Sans facturation'::text
                            ELSE source_1."EtatPaiement"
                        END AS "EtatPaiement",
                        CASE
                            WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN false
                            ELSE source_1."EstPaiementEnRetard"
                        END AS "EstPaiementEnRetard",
                        CASE
                            WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::integer
                            ELSE source_1."JoursAvantEcheance"
                        END AS "JoursAvantEcheance",
                    source_1."NbLignes",
                    source_1."NbArticlesDistincts",
                    source_1."QteTotale",
                    source_1."MontantDetails",
                    source_1."ListeArticles",
                    source_1."EstCommandeSansDetails",
                    source_1."EcartMontantDetails",
                    source_1."EstMontantIncoherent",
                    source_1."EtatControleCommande",
                    source_1."ID_DeviseFk",
                    source_1."DeviseCode",
                    source_1."DeviseLibelle",
                    source_1."ID_Facture",
                    source_1."EstFactureSnapshot",
                    source_1."MontantFacture",
                    source_1."MontantAvoirAEtablir",
                    source_1."AvoirAEtablir",
                    source_1."IdEntiteFk",
                    source_1."ID_TiersFk",
                    source_1."TiersNom",
                    source_1."ID_DestinationFk",
                    source_1."DestinationLibelle",
                    source_1."AvoirImpute",
                    source_1."OrigineBon",
                    source_1."ID_ArticleInitialFk",
                    logistique.fn_nature_bon(source_1."ID_TypeCmdFk") AS "NatureBon"
                   FROM ( SELECT source_1_1."ID_Commande",
                            source_1_1."ID_TypeCmdFk",
                            source_1_1."ID_StatutCmdFk",
                            source_1_1."ID_ClientFk",
                            source_1_1."ID_UserFk",
                            source_1_1."geolocalisationCmd",
                            source_1_1."DateHeureAutoCmd",
                            source_1_1."DateCmd",
                            source_1_1."CodeCmd",
                            source_1_1."RefCmd",
                            source_1_1."MontantHT",
                            source_1_1."MontantTTC",
                            source_1_1."UrlBL",
                            source_1_1."ObsCmd",
                            source_1_1."SelectCmd",
                            source_1_1."DateHeureAutoFacture",
                            source_1_1."DateFacture",
                            source_1_1."CodeFacture",
                            source_1_1."MontantRegleFacture",
                            source_1_1."MontantResteFacture",
                            source_1_1."StatusFacture",
                            source_1_1."ValideRemiseFacture",
                            source_1_1."UrlFacture",
                            source_1_1."ID_ConditionPaiementFk",
                            source_1_1."DateEcheancePaiement",
                            source_1_1."ID_ModePaiementFk",
                            source_1_1."NomClientSaisi",
                            source_1_1."AbrTypeCmd",
                            source_1_1."TypeCmd",
                            source_1_1."SigneCommande",
                            source_1_1."EstCommandeEntree",
                            source_1_1."EstCommandeSortie",
                            source_1_1."AbrStatutCmd",
                            source_1_1."StatutCmd",
                            source_1_1."NomUser",
                            source_1_1."PrenomUser",
                            source_1_1."NomComplet",
                            source_1_1."AbrConditionPaiement",
                            source_1_1."ConditionPaiement",
                            source_1_1."AbrModePaiement",
                            source_1_1."ModePaiement",
                            source_1_1."MontantHTCalc",
                            source_1_1."MontantTTCCalc",
                            source_1_1."MontantRegleFactureCalc",
                            source_1_1."MontantResteFactureCalc",
                            source_1_1."TotalRegleReel",
                            source_1_1."ResteReel",
                            source_1_1."NbReglements",
                            source_1_1."DernierReglement",
                            source_1_1."EtatPaiement",
                            source_1_1."EstPaiementEnRetard",
                            source_1_1."JoursAvantEcheance",
                            source_1_1."NbLignes",
                            source_1_1."NbArticlesDistincts",
                            source_1_1."QteTotale",
                            source_1_1."MontantDetails",
                            source_1_1."ListeArticles",
                            source_1_1."EstCommandeSansDetails",
                            source_1_1."EcartMontantDetails",
                            source_1_1."EstMontantIncoherent",
                            source_1_1."EtatControleCommande",
                            source_1_1."ID_DeviseFk",
                            source_1_1."DeviseCode",
                            source_1_1."DeviseLibelle",
                            source_1_1."ID_Facture",
                            source_1_1."EstFactureSnapshot",
                            source_1_1."MontantFacture",
                            source_1_1."MontantAvoirAEtablir",
                            source_1_1."AvoirAEtablir",
                            source_1_1."IdEntiteFk",
                            source_1_1."ID_TiersFk",
                            source_1_1."TiersNom",
                            source_1_1."ID_DestinationFk",
                            source_1_1."DestinationLibelle",
                            source_1_1."AvoirImpute",
                            c."OrigineBon",
                            c."ID_ArticleInitialFk"
                           FROM (( SELECT b."ID_Commande",
                                    b."ID_TypeCmdFk",
                                    b."ID_StatutCmdFk",
                                    b."ID_ClientFk",
                                    b."ID_UserFk",
                                    b."geolocalisationCmd",
                                    b."DateHeureAutoCmd",
                                    b."DateCmd",
                                    b."CodeCmd",
                                    b."RefCmd",
                                    b."MontantHT",
                                    b."MontantTTC",
                                    b."UrlBL",
                                    b."ObsCmd",
                                    b."SelectCmd",
                                    b."DateHeureAutoFacture",
                                    b."DateFacture",
                                    b."CodeFacture",
                                    b."MontantRegleFacture",
                                    b."MontantResteFacture",
                                    b."StatusFacture",
                                    b."ValideRemiseFacture",
                                    b."UrlFacture",
                                    b."ID_ConditionPaiementFk",
                                    b."DateEcheancePaiement",
                                    b."ID_ModePaiementFk",
                                    b."NomClientSaisi",
                                    b."AbrTypeCmd",
                                    b."TypeCmd",
                                    b."SigneCommande",
                                    b."EstCommandeEntree",
                                    b."EstCommandeSortie",
                                    b."AbrStatutCmd",
                                    b."StatutCmd",
                                    b."NomUser",
                                    b."PrenomUser",
                                    b."NomComplet",
                                    b."AbrConditionPaiement",
                                    b."ConditionPaiement",
                                    b."AbrModePaiement",
                                    b."ModePaiement",
                                    b."MontantHTCalc",
                                    b."MontantTTCCalc",
                                    b."MontantRegleFactureCalc",
                                    b."MontantResteFactureCalc",
                                    b."TotalRegleReel",
                                    b."ResteReel",
                                    b."NbReglements",
                                    b."DernierReglement",
                                    b."EtatPaiement",
                                    b."EstPaiementEnRetard",
                                    b."JoursAvantEcheance",
                                    b."NbLignes",
                                    b."NbArticlesDistincts",
                                    b."QteTotale",
                                    b."MontantDetails",
                                    b."ListeArticles",
                                    b."EstCommandeSansDetails",
                                    b."EcartMontantDetails",
                                    b."EstMontantIncoherent",
                                    b."EtatControleCommande",
                                    b."ID_DeviseFk",
                                    b."DeviseCode",
                                    b."DeviseLibelle",
                                    b."ID_Facture",
                                    b."EstFactureSnapshot",
                                    b."MontantFacture",
                                    (pending.amount)::numeric(12,2) AS "MontantAvoirAEtablir",
                                    (pending.amount > (0)::numeric) AS "AvoirAEtablir",
                                    b."IdEntiteFk",
                                    b."ID_TiersFk",
                                    b."TiersNom",
                                    b."ID_DestinationFk",
                                    b."DestinationLibelle",
                                    (COALESCE(cr.total, (0)::numeric))::numeric(12,2) AS "AvoirImpute"
                                   FROM ((( SELECT s."ID_Commande",
    s."ID_TypeCmdFk",
    s."ID_StatutCmdFk",
    s."ID_ClientFk",
    s."ID_UserFk",
    s."geolocalisationCmd",
    s."DateHeureAutoCmd",
    s."DateCmd",
    s."CodeCmd",
    s."RefCmd",
    s."MontantHT",
    s."MontantTTC",
    s."UrlBL",
    s."ObsCmd",
    s."SelectCmd",
    s."DateHeureAutoFacture",
    s."DateFacture",
    s."CodeFacture",
    s."MontantRegleFacture",
    s."MontantResteFacture",
    s."StatusFacture",
    s."ValideRemiseFacture",
    s."UrlFacture",
    s."ID_ConditionPaiementFk",
    s."DateEcheancePaiement",
    s."ID_ModePaiementFk",
    s."NomClientSaisi",
    s."AbrTypeCmd",
    s."TypeCmd",
    s."SigneCommande",
    s."EstCommandeEntree",
    s."EstCommandeSortie",
    s."AbrStatutCmd",
    s."StatutCmd",
    s."NomUser",
    s."PrenomUser",
    s."NomComplet",
    s."AbrConditionPaiement",
    s."ConditionPaiement",
    s."AbrModePaiement",
    s."ModePaiement",
    s."MontantHTCalc",
    s."MontantTTCCalc",
    s."MontantRegleFactureCalc",
    s."MontantResteFactureCalc",
    s."TotalRegleReel",
    s."ResteReel",
    s."NbReglements",
    s."DernierReglement",
    s."EtatPaiement",
    s."EstPaiementEnRetard",
    s."JoursAvantEcheance",
    s."NbLignes",
    s."NbArticlesDistincts",
    s."QteTotale",
    s."MontantDetails",
    s."ListeArticles",
    s."EstCommandeSansDetails",
    s."EcartMontantDetails",
    s."EstMontantIncoherent",
    s."EtatControleCommande",
    s."ID_DeviseFk",
    s."DeviseCode",
    s."DeviseLibelle",
    s."ID_Facture",
    s."EstFactureSnapshot",
    s."MontantFacture",
    s."MontantAvoirAEtablir",
    s."AvoirAEtablir",
    s."IdEntiteFk",
    s."ID_TiersFk",
    s."TiersNom",
    c_1."ID_DestinationFk",
    d.label AS "DestinationLibelle"
   FROM ((( SELECT source_1_1_1."ID_Commande",
      source_1_1_1."ID_TypeCmdFk",
      source_1_1_1."ID_StatutCmdFk",
      source_1_1_1."ID_ClientFk",
      source_1_1_1."ID_UserFk",
      source_1_1_1."geolocalisationCmd",
      source_1_1_1."DateHeureAutoCmd",
      source_1_1_1."DateCmd",
      source_1_1_1."CodeCmd",
      source_1_1_1."RefCmd",
      source_1_1_1."MontantHT",
      source_1_1_1."MontantTTC",
      source_1_1_1."UrlBL",
      source_1_1_1."ObsCmd",
      source_1_1_1."SelectCmd",
      source_1_1_1."DateHeureAutoFacture",
      source_1_1_1."DateFacture",
      source_1_1_1."CodeFacture",
      source_1_1_1."MontantRegleFacture",
      source_1_1_1."MontantResteFacture",
      source_1_1_1."StatusFacture",
      source_1_1_1."ValideRemiseFacture",
      source_1_1_1."UrlFacture",
      source_1_1_1."ID_ConditionPaiementFk",
      source_1_1_1."DateEcheancePaiement",
      source_1_1_1."ID_ModePaiementFk",
      source_1_1_1."NomClientSaisi",
      source_1_1_1."AbrTypeCmd",
      source_1_1_1."TypeCmd",
      source_1_1_1."SigneCommande",
      source_1_1_1."EstCommandeEntree",
      source_1_1_1."EstCommandeSortie",
      source_1_1_1."AbrStatutCmd",
      source_1_1_1."StatutCmd",
      source_1_1_1."NomUser",
      source_1_1_1."PrenomUser",
      source_1_1_1."NomComplet",
      source_1_1_1."AbrConditionPaiement",
      source_1_1_1."ConditionPaiement",
      source_1_1_1."AbrModePaiement",
      source_1_1_1."ModePaiement",
      source_1_1_1."MontantHTCalc",
      source_1_1_1."MontantTTCCalc",
      source_1_1_1."MontantRegleFactureCalc",
      source_1_1_1."MontantResteFactureCalc",
      source_1_1_1."TotalRegleReel",
      source_1_1_1."ResteReel",
      source_1_1_1."NbReglements",
      source_1_1_1."DernierReglement",
      source_1_1_1."EtatPaiement",
      source_1_1_1."EstPaiementEnRetard",
      source_1_1_1."JoursAvantEcheance",
      source_1_1_1."NbLignes",
      source_1_1_1."NbArticlesDistincts",
      source_1_1_1."QteTotale",
      source_1_1_1."MontantDetails",
      source_1_1_1."ListeArticles",
      source_1_1_1."EstCommandeSansDetails",
      source_1_1_1."EcartMontantDetails",
      source_1_1_1."EstMontantIncoherent",
      source_1_1_1."EtatControleCommande",
      source_1_1_1."ID_DeviseFk",
      source_1_1_1."DeviseCode",
      source_1_1_1."DeviseLibelle",
      source_1_1_1."ID_Facture",
      source_1_1_1."EstFactureSnapshot",
      source_1_1_1."MontantFacture",
      source_1_1_1."MontantAvoirAEtablir",
      source_1_1_1."AvoirAEtablir",
      r."IdEntiteFk",
      r."ID_TiersFk",
      t."Nom" AS "TiersNom"
     FROM ((( SELECT base."ID_Commande",
        base."ID_TypeCmdFk",
        base."ID_StatutCmdFk",
        base."ID_ClientFk",
        base."ID_UserFk",
        base."geolocalisationCmd",
        base."DateHeureAutoCmd",
        base."DateCmd",
        base."CodeCmd",
        base."RefCmd",
        base."MontantHT",
        base."MontantTTC",
        base."UrlBL",
        base."ObsCmd",
        base."SelectCmd",
        base."DateHeureAutoFacture",
        base."DateFacture",
        base."CodeFacture",
        COALESCE(f_1."TotalRegle", base."MontantRegleFacture") AS "MontantRegleFacture",
        COALESCE(f_1."Reste", base."MontantResteFacture") AS "MontantResteFacture",
        base."StatusFacture",
        base."ValideRemiseFacture",
        base."UrlFacture",
        base."ID_ConditionPaiementFk",
        base."DateEcheancePaiement",
        base."ID_ModePaiementFk",
        base."NomClientSaisi",
        base."AbrTypeCmd",
        base."TypeCmd",
        base."SigneCommande",
        base."EstCommandeEntree",
        base."EstCommandeSortie",
        base."AbrStatutCmd",
        base."StatutCmd",
        base."NomUser",
        base."PrenomUser",
        base."NomComplet",
        base."AbrConditionPaiement",
        base."ConditionPaiement",
        base."AbrModePaiement",
        base."ModePaiement",
        base."MontantHTCalc",
        base."MontantTTCCalc",
        COALESCE(f_1."TotalRegle", base."MontantRegleFactureCalc") AS "MontantRegleFactureCalc",
        COALESCE(f_1."Reste", base."MontantResteFactureCalc") AS "MontantResteFactureCalc",
        COALESCE(f_1."TotalRegle", base."TotalRegleReel") AS "TotalRegleReel",
        COALESCE(f_1."Reste", base."ResteReel") AS "ResteReel",
        base."NbReglements",
        base."DernierReglement",
        COALESCE(f_1."EtatReglement", base."EtatPaiement") AS "EtatPaiement",
        COALESCE(f_1."EstEnRetard", base."EstPaiementEnRetard") AS "EstPaiementEnRetard",
        base."JoursAvantEcheance",
        base."NbLignes",
        base."NbArticlesDistincts",
        base."QteTotale",
        base."MontantDetails",
        base."ListeArticles",
        base."EstCommandeSansDetails",
        base."EcartMontantDetails",
        base."EstMontantIncoherent",
        base."EtatControleCommande",
        base."ID_DeviseFk",
        COALESCE(f_1."DeviseCode", base."DeviseCode") AS "DeviseCode",
        COALESCE(f_1."DeviseLibelle", base."DeviseLibelle") AS "DeviseLibelle",
        f_1."ID_Facture",
        (f_1."ID_Facture" IS NOT NULL) AS "EstFactureSnapshot",
        (
      CASE
       WHEN (NULLIF(btrim((base."CodeFacture")::text), ''::text) IS NOT NULL) THEN COALESCE(f_1."MontantTTC", base."MontantTTC")
       ELSE NULL::numeric
      END)::numeric(12,2) AS "MontantFacture",
        (COALESCE(f_1."MontantAvoirAEtablir", (0)::numeric))::numeric(12,2) AS "MontantAvoirAEtablir",
        COALESCE(f_1."AvoirAEtablir", false) AS "AvoirAEtablir"
       FROM (( SELECT historique."ID_Commande",
          historique."ID_TypeCmdFk",
          historique."ID_StatutCmdFk",
          historique."ID_ClientFk",
          historique."ID_UserFk",
          historique."geolocalisationCmd",
          historique."DateHeureAutoCmd",
          historique."DateCmd",
          historique."CodeCmd",
          historique."RefCmd",
          historique."MontantHT",
          historique."MontantTTC",
          historique."UrlBL",
          historique."ObsCmd",
          historique."SelectCmd",
          historique."DateHeureAutoFacture",
          historique."DateFacture",
          historique."CodeFacture",
          historique."MontantRegleFacture",
          historique."MontantResteFacture",
          historique."StatusFacture",
          historique."ValideRemiseFacture",
          historique."UrlFacture",
          historique."ID_ConditionPaiementFk",
          historique."DateEcheancePaiement",
          historique."ID_ModePaiementFk",
          historique."NomClientSaisi",
          historique."AbrTypeCmd",
          historique."TypeCmd",
          historique."SigneCommande",
          historique."EstCommandeEntree",
          historique."EstCommandeSortie",
          historique."AbrStatutCmd",
          historique."StatutCmd",
          historique."NomUser",
          historique."PrenomUser",
          historique."NomComplet",
          historique."AbrConditionPaiement",
          historique."ConditionPaiement",
          historique."AbrModePaiement",
          historique."ModePaiement",
          historique."MontantHTCalc",
          historique."MontantTTCCalc",
          historique."MontantRegleFactureCalc",
          historique."MontantResteFactureCalc",
          historique."TotalRegleReel",
          historique."ResteReel",
          historique."NbReglements",
          historique."DernierReglement",
          historique."EtatPaiement",
          historique."EstPaiementEnRetard",
          historique."JoursAvantEcheance",
          historique."NbLignes",
          historique."NbArticlesDistincts",
          historique."QteTotale",
          historique."MontantDetails",
          historique."ListeArticles",
          historique."EstCommandeSansDetails",
          historique."EcartMontantDetails",
          historique."EstMontantIncoherent",
          historique."EtatControleCommande",
          source_1_1_1_1."ID_DeviseFk",
          logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
          (devise."NomGenerique")::text AS "DeviseLibelle"
         FROM ((( WITH cd_stats AS (
           SELECT cd."ID_CmdFk",
              (count(*))::integer AS "NbLignes",
              (count(DISTINCT cd."ID_ArticleFk"))::integer AS "NbArticlesDistincts",
              (COALESCE(sum(COALESCE(cd."QteCmdDetail", (0)::numeric)), (0)::numeric))::numeric(14,3) AS "QteTotale",
              (COALESCE(sum(round((COALESCE(cd."QteCmdDetail", (0)::numeric) * COALESCE(cd."PUCmdDetail", (0)::numeric)), 2)), (0)::numeric))::numeric(12,2) AS "MontantDetails",
              string_agg(DISTINCT (a."NomArticle")::text, ', '::text ORDER BY (a."NomArticle")::text) AS "ListeArticles"
             FROM (logistique."T_CommandeDetail" cd
               LEFT JOIN logistique."T_Article" a ON ((a."ID_Article" = cd."ID_ArticleFk")))
            GROUP BY cd."ID_CmdFk"
          ), reg_stats AS (
           SELECT r_1."CodeFactureFk",
              (COALESCE(sum(COALESCE(r_1."MontantRegle", (0)::numeric)), (0)::numeric))::numeric(12,2) AS "TotalRegleReel",
              (count(*))::integer AS "NbReglements",
              max(r_1."DateReglement") AS "DernierReglement"
             FROM logistique."T_Reglements" r_1
            GROUP BY r_1."CodeFactureFk"
          )
         SELECT c_1_1."ID_Commande",
            c_1_1."ID_TypeCmdFk",
            c_1_1."ID_StatutCmdFk",
            c_1_1."ID_ClientFk",
            c_1_1."ID_UserFk",
            c_1_1."geolocalisationCmd",
            c_1_1."DateHeureAutoCmd",
            c_1_1."DateCmd",
            c_1_1."CodeCmd",
            c_1_1."RefCmd",
            c_1_1."MontantHT",
            c_1_1."MontantTTC",
            c_1_1."UrlBL",
            c_1_1."ObsCmd",
            c_1_1."SelectCmd",
            c_1_1."DateHeureAutoFacture",
            c_1_1."DateFacture",
            c_1_1."CodeFacture",
            c_1_1."MontantRegleFacture",
            c_1_1."MontantResteFacture",
            c_1_1."StatusFacture",
            c_1_1."ValideRemiseFacture",
            c_1_1."UrlFacture",
            c_1_1."ID_ConditionPaiementFk",
            c_1_1."DateEcheancePaiement",
            c_1_1."ID_ModePaiementFk",
            c_1_1."NomClientSaisi",
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
            (COALESCE(c_1_1."MontantHT", (0)::numeric))::numeric(12,2) AS "MontantHTCalc",
            (COALESCE(c_1_1."MontantTTC", (0)::numeric))::numeric(12,2) AS "MontantTTCCalc",
            (COALESCE(c_1_1."MontantRegleFacture", (0)::numeric))::numeric(12,2) AS "MontantRegleFactureCalc",
            (COALESCE(c_1_1."MontantResteFacture", (0)::numeric))::numeric(12,2) AS "MontantResteFactureCalc",
            (COALESCE(reg_stats."TotalRegleReel", (0)::numeric))::numeric(12,2) AS "TotalRegleReel",
            ((COALESCE(c_1_1."MontantTTC", (0)::numeric) - COALESCE(reg_stats."TotalRegleReel", (0)::numeric)))::numeric(12,2) AS "ResteReel",
            COALESCE(reg_stats."NbReglements", 0) AS "NbReglements",
            reg_stats."DernierReglement",
          CASE
           WHEN (c_1_1."CodeFacture" IS NULL) THEN 'Non facturée'::text
           WHEN (COALESCE(c_1_1."MontantTTC", (0)::numeric) = (0)::numeric) THEN 'Montant nul'::text
           WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", (0)::numeric), (0)::numeric) <= (0)::numeric) THEN 'Non réglée'::text
           WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", (0)::numeric), (0)::numeric) < COALESCE(c_1_1."MontantTTC", (0)::numeric)) THEN 'Partiellement réglée'::text
           WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", (0)::numeric), (0)::numeric) >= COALESCE(c_1_1."MontantTTC", (0)::numeric)) THEN 'Réglée'::text
           ELSE 'Indéterminé'::text
          END AS "EtatPaiement",
            ((c_1_1."DateEcheancePaiement" IS NOT NULL) AND ((c_1_1."DateEcheancePaiement")::date < CURRENT_DATE) AND ((COALESCE(c_1_1."MontantTTC", (0)::numeric) - COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", (0)::numeric), (0)::numeric)) > (0)::numeric)) AS "EstPaiementEnRetard",
          CASE
           WHEN (c_1_1."DateEcheancePaiement" IS NOT NULL) THEN ((c_1_1."DateEcheancePaiement")::date - CURRENT_DATE)
           ELSE NULL::integer
          END AS "JoursAvantEcheance",
            COALESCE(cd_stats."NbLignes", 0) AS "NbLignes",
            COALESCE(cd_stats."NbArticlesDistincts", 0) AS "NbArticlesDistincts",
            (COALESCE(cd_stats."QteTotale", (0)::numeric))::numeric(14,3) AS "QteTotale",
            (COALESCE(cd_stats."MontantDetails", (0)::numeric))::numeric(12,2) AS "MontantDetails",
            cd_stats."ListeArticles",
            (COALESCE(cd_stats."NbLignes", 0) = 0) AS "EstCommandeSansDetails",
            ((COALESCE(c_1_1."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric)))::numeric(12,2) AS "EcartMontantDetails",
            (abs((COALESCE(c_1_1."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric))) > 0.01) AS "EstMontantIncoherent",
          CASE
           WHEN (COALESCE(cd_stats."NbLignes", 0) = 0) THEN 'Sans détails'::text
           WHEN (abs((COALESCE(c_1_1."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric))) > 0.01) THEN 'Montant incohérent'::text
           ELSE 'Cohérente'::text
          END AS "EtatControleCommande"
           FROM (((((((logistique."T_Commande" c_1_1
             LEFT JOIN systeme."T_Utilisateurs" u ON ((c_1_1."ID_UserFk" = u."IdUser")))
             LEFT JOIN referentiel."T_Generique" type_cmd ON ((c_1_1."ID_TypeCmdFk" = type_cmd."ID_Generique")))
             LEFT JOIN referentiel."T_Generique" statut_cmd ON ((c_1_1."ID_StatutCmdFk" = statut_cmd."ID_Generique")))
             LEFT JOIN referentiel."T_Generique" condition_paiement ON ((c_1_1."ID_ConditionPaiementFk" = condition_paiement."ID_Generique")))
             LEFT JOIN referentiel."T_Generique" mode_paiement ON ((c_1_1."ID_ModePaiementFk" = mode_paiement."ID_Generique")))
             LEFT JOIN cd_stats ON ((cd_stats."ID_CmdFk" = c_1_1."ID_Commande")))
             LEFT JOIN reg_stats ON (((reg_stats."CodeFactureFk")::text = (c_1_1."CodeFacture")::text)))) historique
           LEFT JOIN logistique."T_Commande" source_1_1_1_1 ON ((source_1_1_1_1."ID_Commande" = historique."ID_Commande")))
           LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1_1_1_1."ID_DeviseFk")))) base
         LEFT JOIN logistique."V_Facture" f_1 ON ((f_1."ID_CommandeFk" = base."ID_Commande")))) source_1_1_1
       LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source_1_1_1."ID_Commande")))
       LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")))) s
     JOIN logistique."T_Commande" c_1 ON ((c_1."ID_Commande" = s."ID_Commande")))
     LEFT JOIN geolocalisation."V_DestinationLogistique" d ON ((d.id = c_1."ID_DestinationFk")))) b
                                     LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS total
   FROM logistique."T_AvoirAffectation"
  WHERE ("T_AvoirAffectation"."ID_CommandeCibleFk" = b."ID_Commande")) cr ON (true))
                                     LEFT JOIN LATERAL ( SELECT logistique.fn_montant_avoir_attente(b."ID_Commande") AS amount) pending ON (true))) source_1_1
                             JOIN logistique."T_Commande" c ON ((c."ID_Commande" = source_1_1."ID_Commande")))) source_1) source
             LEFT JOIN logistique."T_BonCodeHistorique" h ON ((h."ID_Commande" = source."ID_Commande")))) v
     LEFT JOIN logistique."T_Facture" f ON ((f."ID_CommandeFk" = v."ID_Commande")));

--
-- Name: VIEW "V_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Commande" IS 'Registre documentaire et suivi des montants, avec fiscalité de la facture émise jointe sans modifier le stock ni les totaux physiques du bon.';

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

COMMENT ON COLUMN logistique."V_Commande"."CodeCmd" IS 'Code actuel du bon après nomenclature06 ; AncienCodeCmd et RenumeroteLe conservent sa correspondance historique.';

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

COMMENT ON COLUMN logistique."V_Commande"."MontantRegleFacture" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_Commande"."MontantResteFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantResteFacture" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

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

COMMENT ON COLUMN logistique."V_Commande"."AbrTypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Commande"."TypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."TypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

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

COMMENT ON COLUMN logistique."V_Commande"."AbrStatutCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Commande"."StatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."StatutCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

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

COMMENT ON COLUMN logistique."V_Commande"."AbrConditionPaiement" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Commande"."ConditionPaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ConditionPaiement" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Commande"."AbrModePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."AbrModePaiement" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Commande"."ModePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ModePaiement" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

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

COMMENT ON COLUMN logistique."V_Commande"."MontantRegleFactureCalc" IS 'Valeur de suivi d’une opération physique ou facturée ; NULL pour CMD, qui ne produit ni stock, règlement, dette ou échéance de facture réelle.';

--
-- Name: COLUMN "V_Commande"."MontantResteFactureCalc"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantResteFactureCalc" IS 'Valeur de suivi d’une opération physique ou facturée ; NULL pour CMD, qui ne produit ni stock, règlement, dette ou échéance de facture réelle.';

--
-- Name: COLUMN "V_Commande"."TotalRegleReel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."TotalRegleReel" IS 'Valeur de suivi d’une opération physique ou facturée ; NULL pour CMD, qui ne produit ni stock, règlement, dette ou échéance de facture réelle.';

--
-- Name: COLUMN "V_Commande"."ResteReel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ResteReel" IS 'Valeur de suivi d’une opération physique ou facturée ; NULL pour CMD, qui ne produit ni stock, règlement, dette ou échéance de facture réelle.';

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

COMMENT ON COLUMN logistique."V_Commande"."EtatPaiement" IS 'État réel de facturation ; Sans facturation pour CMD, qui ne constitue ni une facture impayée ni une dette.';

--
-- Name: COLUMN "V_Commande"."EstPaiementEnRetard"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EstPaiementEnRetard" IS 'Alerte sur une facture échue ; toujours faux pour un bon de commande CMD.';

--
-- Name: COLUMN "V_Commande"."JoursAvantEcheance"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."JoursAvantEcheance" IS 'Valeur de suivi d’une opération physique ou facturée ; NULL pour CMD, qui ne produit ni stock, règlement, dette ou échéance de facture réelle.';

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
-- Name: COLUMN "V_Commande"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';

--
-- Name: COLUMN "V_Commande"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DeviseCode" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_Commande"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DeviseLibelle" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_Commande"."ID_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_Facture" IS 'Identité interne de la facture, indépendante du code lisible.';

--
-- Name: COLUMN "V_Commande"."EstFactureSnapshot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."EstFactureSnapshot" IS 'Vrai lorsqu’un instantané financier versionné existe.';

--
-- Name: COLUMN "V_Commande"."MontantFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantFacture" IS 'Montant du snapshot émis, NULL pour un bon non facturé ; historique conservé en compatibilité.';

--
-- Name: COLUMN "V_Commande"."MontantAvoirAEtablir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantAvoirAEtablir" IS 'Contrevaleur des retours postérieurs à l’émission ; aucun remboursement créé.';

--
-- Name: COLUMN "V_Commande"."AvoirAEtablir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."AvoirAEtablir" IS 'Vrai si des retours postérieurs à la facture ne sont pas encore couverts par un avoir.';

--
-- Name: COLUMN "V_Commande"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Commande"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_TiersFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Commande"."TiersNom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."TiersNom" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Commande"."ID_DestinationFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_DestinationFk" IS 'Lieu référencé ou chemin géographique existant : ID_DestinationFk. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_Commande"."DestinationLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."DestinationLibelle" IS 'Lieu référencé ou chemin géographique existant : DestinationLibelle. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_Commande"."AvoirImpute"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."AvoirImpute" IS 'Imputations d’avoirs au bon facturé, distinctes des encaissements.';

--
-- Name: COLUMN "V_Commande"."OrigineBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."OrigineBon" IS 'Origine durable distincte du type de bon: stock_initial, reprise_mouvement ou absence pour les autres flux.';

--
-- Name: COLUMN "V_Commande"."ID_ArticleInitialFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."ID_ArticleInitialFk" IS 'Article source du bon technique initial ou de reprise; les lignes et mouvements conservent leurs FK existantes.';

--
-- Name: COLUMN "V_Commande"."NatureBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."NatureBon" IS 'entree ou sortie pour un document physique ; commande pour CMD explicite du référentiel ; NULL si un ancien type est inconnu.';

--
-- Name: COLUMN "V_Commande"."AncienCodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."AncienCodeCmd" IS 'Code exact avant la nomenclature06 si ce bon a été renommé ; issu du journal immuable, sans réécrire le document ni les écritures émises.';

--
-- Name: COLUMN "V_Commande"."RenumeroteLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."RenumeroteLe" IS 'Instant de la reprise06 de ce bon ; absent pour un code déjà canonique ou une création ultérieure.';

--
-- Name: COLUMN "V_Commande"."TauxTVAFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."TauxTVAFacture" IS 'Taux historique de la facture émise, distinct du taux courant de l’entreprise.';

--
-- Name: COLUMN "V_Commande"."MontantTVAFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantTVAFacture" IS 'TVA de la facture émise, sans modification des totaux physiques du bon.';

--
-- Name: COLUMN "V_Commande"."MontantHTFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Commande"."MontantHTFacture" IS 'Montant HT immuable de la facture émise ; les retours postérieurs produisent un avoir séparé.';

--
-- Name: V_CommandeDetail; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CommandeDetail" AS
 SELECT source."ID_CmdFk",
    source."ID_Commande",
    source."DateCmd",
    source."CodeCmd",
    source."CodeFacture",
    source."ID_TypeCmdFk",
    source."AbrTypeCmd",
    source."TypeCmd",
    source."SigneCommande",
    source."ID_StatutCmdFk",
    source."ID_StatutCmd",
    source."AbrStatutCmd",
    source."StatutCmd",
    source."ID_ArticleFk",
    source."CodeArticleInterne",
    source."NomArticle",
    source."ID_UniteFk",
    source."AbrUnite",
    source."StockActuel",
    source."StockAvantLigneTheorique",
    source."QteCmdDetail",
    source."PUCmdDetail",
    source."MontantLigne",
    source."ObsCmdDetail",
    source."RemiseCmdDetail",
    source."LieuCmdDetail",
    source."SelectCmdDetail",
    source."EtatLigne",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    source."IdEntiteFk",
    source."ID_TiersFk",
    source."TiersNom",
    source."NatureBon",
    h."AncienCodeCmd",
    h."RenumeroteLe"
   FROM (( SELECT source_1."ID_CmdFk",
            source_1."ID_Commande",
            source_1."DateCmd",
            source_1."CodeCmd",
            source_1."CodeFacture",
            source_1."ID_TypeCmdFk",
            source_1."AbrTypeCmd",
            source_1."TypeCmd",
            source_1."SigneCommande",
            source_1."ID_StatutCmdFk",
            source_1."ID_StatutCmd",
            source_1."AbrStatutCmd",
            source_1."StatutCmd",
            source_1."ID_ArticleFk",
            source_1."CodeArticleInterne",
            source_1."NomArticle",
            source_1."ID_UniteFk",
            source_1."AbrUnite",
            source_1."StockActuel",
            (
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                    ELSE source_1."StockAvantLigneTheorique"
                END)::numeric(14,3) AS "StockAvantLigneTheorique",
            source_1."QteCmdDetail",
            source_1."PUCmdDetail",
            source_1."MontantLigne",
            source_1."ObsCmdDetail",
            source_1."RemiseCmdDetail",
            source_1."LieuCmdDetail",
            source_1."SelectCmdDetail",
            source_1."EtatLigne",
            source_1."ID_DeviseFk",
            source_1."DeviseCode",
            source_1."DeviseLibelle",
            source_1."IdEntiteFk",
            source_1."ID_TiersFk",
            source_1."TiersNom",
            logistique.fn_nature_bon(source_1."ID_TypeCmdFk") AS "NatureBon"
           FROM ( SELECT source_1_1."ID_CmdFk",
                    source_1_1."ID_Commande",
                    source_1_1."DateCmd",
                    source_1_1."CodeCmd",
                    source_1_1."CodeFacture",
                    source_1_1."ID_TypeCmdFk",
                    source_1_1."AbrTypeCmd",
                    source_1_1."TypeCmd",
                    source_1_1."SigneCommande",
                    source_1_1."ID_StatutCmdFk",
                    source_1_1."ID_StatutCmd",
                    source_1_1."AbrStatutCmd",
                    source_1_1."StatutCmd",
                    source_1_1."ID_ArticleFk",
                    source_1_1."CodeArticleInterne",
                    source_1_1."NomArticle",
                    source_1_1."ID_UniteFk",
                    source_1_1."AbrUnite",
                    source_1_1."StockActuel",
                    source_1_1."StockAvantLigneTheorique",
                    source_1_1."QteCmdDetail",
                    source_1_1."PUCmdDetail",
                    source_1_1."MontantLigne",
                    source_1_1."ObsCmdDetail",
                    source_1_1."RemiseCmdDetail",
                    source_1_1."LieuCmdDetail",
                    source_1_1."SelectCmdDetail",
                    source_1_1."EtatLigne",
                    source_1_1."ID_DeviseFk",
                    source_1_1."DeviseCode",
                    source_1_1."DeviseLibelle",
                    r."IdEntiteFk",
                    r."ID_TiersFk",
                    t."Nom" AS "TiersNom"
                   FROM ((( SELECT historique."ID_CmdFk",
                            historique."ID_Commande",
                            historique."DateCmd",
                            historique."CodeCmd",
                            historique."CodeFacture",
                            historique."ID_TypeCmdFk",
                            historique."AbrTypeCmd",
                            historique."TypeCmd",
                            historique."SigneCommande",
                            historique."ID_StatutCmdFk",
                            historique."ID_StatutCmd",
                            historique."AbrStatutCmd",
                            historique."StatutCmd",
                            historique."ID_ArticleFk",
                            historique."CodeArticleInterne",
                            historique."NomArticle",
                            historique."ID_UniteFk",
                            historique."AbrUnite",
                            historique."StockActuel",
                            historique."StockAvantLigneTheorique",
                            historique."QteCmdDetail",
                            historique."PUCmdDetail",
                            historique."MontantLigne",
                            historique."ObsCmdDetail",
                            historique."RemiseCmdDetail",
                            historique."LieuCmdDetail",
                            historique."SelectCmdDetail",
                            historique."EtatLigne",
                            source_1_1_1."ID_DeviseFk",
                            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
                            (devise."NomGenerique")::text AS "DeviseLibelle"
                           FROM ((( SELECT d."ID_CmdFk",
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
                                     LEFT JOIN referentiel."T_Generique" type_cmd ON ((c."ID_TypeCmdFk" = type_cmd."ID_Generique")))
                                     LEFT JOIN referentiel."T_Generique" statut_cmd ON ((c."ID_StatutCmdFk" = statut_cmd."ID_Generique")))
                                     LEFT JOIN referentiel."T_Generique" unite ON ((a."ID_UniteFk" = unite."ID_Generique")))) historique
                             LEFT JOIN logistique."T_Commande" source_1_1_1 ON ((source_1_1_1."ID_Commande" = historique."ID_CmdFk")))
                             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1_1_1."ID_DeviseFk")))) source_1_1
                     LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source_1_1."ID_Commande")))
                     LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")))) source_1) source
     LEFT JOIN logistique."T_BonCodeHistorique" h ON ((h."ID_Commande" = source."ID_Commande")));

--
-- Name: VIEW "V_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CommandeDetail" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

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

COMMENT ON COLUMN logistique."V_CommandeDetail"."CodeCmd" IS 'Code actuel du bon parent ; l’ancien code reste consultable dans AncienCodeCmd, sans changer la clé ID_CmdFk.';

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

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrTypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_CommandeDetail"."TypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."TypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

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

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrStatutCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_CommandeDetail"."StatutCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."StatutCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

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

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrUnite" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_CommandeDetail"."StockActuel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."StockActuel" IS 'Quantité courante de l’article, distincte d’un stock historique. Expression projetée : COALESCE(a."QteArticle", 0::numeric)::numeric(14,3) AS "StockActuel".';

--
-- Name: COLUMN "V_CommandeDetail"."StockAvantLigneTheorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."StockAvantLigneTheorique" IS 'Stock avant l’effet physique de la ligne ; NULL pour CMD, qui ne modifie et ne réserve aucun stock.';

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
-- Name: COLUMN "V_CommandeDetail"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';

--
-- Name: COLUMN "V_CommandeDetail"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_CommandeDetail"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_CommandeDetail"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_CommandeDetail"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_TiersFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_CommandeDetail"."TiersNom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."TiersNom" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_CommandeDetail"."NatureBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."NatureBon" IS 'entree ou sortie pour un document physique ; commande pour CMD explicite du référentiel ; NULL si un ancien type est inconnu.';

--
-- Name: COLUMN "V_CommandeDetail"."AncienCodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."AncienCodeCmd" IS 'Code exact avant la nomenclature06 si ce bon a été renommé ; issu du journal immuable, sans réécrire le document ni les écritures émises.';

--
-- Name: COLUMN "V_CommandeDetail"."RenumeroteLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeDetail"."RenumeroteLe" IS 'Instant de la reprise06 de ce bon ; absent pour un code déjà canonique ou une création ultérieure.';

--
-- Name: V_CommandeOverview; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CommandeOverview" AS
 SELECT source."ID_Commande",
    source."DateCmd",
    source."CodeCmd",
    source."ID_TypeCmdFk",
    source."AbrTypeCmd",
    source."TypeCmd",
    source."ID_StatutCmdFk",
    source."AbrStatutCmd",
    source."StatutCmd",
    source."ID_ClientFk",
    source."NomClientSaisi",
    source."MontantHT",
    source."MontantTTC",
    source."MontantRegleFacture",
    source."MontantResteFacture",
    source."EtatPaiement",
    source."StatusFacture",
    source."DateFacture",
    source."CodeFacture",
    source."DateEcheancePaiement",
    source."NbLignes",
    source."NbArticlesDistincts",
    source."QteTotale",
    source."MontantDetails",
    source."ListeArticles",
    source."EstCommandeSansDetails",
    source."EstMontantIncoherent",
    source."EtatControleCommande",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    source."NatureBon",
    h."AncienCodeCmd",
    h."RenumeroteLe"
   FROM (( SELECT source_1."ID_Commande",
            source_1."DateCmd",
            source_1."CodeCmd",
            source_1."ID_TypeCmdFk",
            source_1."AbrTypeCmd",
            source_1."TypeCmd",
            source_1."ID_StatutCmdFk",
            source_1."AbrStatutCmd",
            source_1."StatutCmd",
            source_1."ID_ClientFk",
            source_1."NomClientSaisi",
            source_1."MontantHT",
            source_1."MontantTTC",
            source_1."MontantRegleFacture",
            source_1."MontantResteFacture",
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN 'Sans facturation'::text
                    ELSE source_1."EtatPaiement"
                END AS "EtatPaiement",
            source_1."StatusFacture",
            source_1."DateFacture",
            source_1."CodeFacture",
            source_1."DateEcheancePaiement",
            source_1."NbLignes",
            source_1."NbArticlesDistincts",
            source_1."QteTotale",
            source_1."MontantDetails",
            source_1."ListeArticles",
            source_1."EstCommandeSansDetails",
            source_1."EstMontantIncoherent",
            source_1."EtatControleCommande",
            source_1."ID_DeviseFk",
            source_1."DeviseCode",
            source_1."DeviseLibelle",
            logistique.fn_nature_bon(source_1."ID_TypeCmdFk") AS "NatureBon"
           FROM ( SELECT historique."ID_Commande",
                    historique."DateCmd",
                    historique."CodeCmd",
                    historique."ID_TypeCmdFk",
                    historique."AbrTypeCmd",
                    historique."TypeCmd",
                    historique."ID_StatutCmdFk",
                    historique."AbrStatutCmd",
                    historique."StatutCmd",
                    historique."ID_ClientFk",
                    historique."NomClientSaisi",
                    historique."MontantHT",
                    historique."MontantTTC",
                    historique."MontantRegleFacture",
                    historique."MontantResteFacture",
                    historique."EtatPaiement",
                    historique."StatusFacture",
                    historique."DateFacture",
                    historique."CodeFacture",
                    historique."DateEcheancePaiement",
                    historique."NbLignes",
                    historique."NbArticlesDistincts",
                    historique."QteTotale",
                    historique."MontantDetails",
                    historique."ListeArticles",
                    historique."EstCommandeSansDetails",
                    historique."EstMontantIncoherent",
                    historique."EtatControleCommande",
                    source_1_1."ID_DeviseFk",
                    logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
                    (devise."NomGenerique")::text AS "DeviseLibelle"
                   FROM ((( SELECT c."ID_Commande",
                            c."DateCmd",
                            c."CodeCmd",
                            c."ID_TypeCmdFk",
                            c."AbrTypeCmd",
                            c."TypeCmd",
                            c."ID_StatutCmdFk",
                            c."AbrStatutCmd",
                            c."StatutCmd",
                            c."ID_ClientFk",
                            c."NomClientSaisi",
                            c."MontantHT",
                            c."MontantTTC",
                            c."MontantRegleFacture",
                            c."MontantResteFacture",
                            c."EtatPaiement",
                            c."StatusFacture",
                            c."DateFacture",
                            c."CodeFacture",
                            c."DateEcheancePaiement",
                            c."NbLignes",
                            c."NbArticlesDistincts",
                            c."QteTotale",
                            c."MontantDetails",
                            c."ListeArticles",
                            c."EstCommandeSansDetails",
                            c."EstMontantIncoherent",
                            c."EtatControleCommande"
                           FROM logistique."V_Commande" c) historique
                     LEFT JOIN logistique."T_Commande" source_1_1 ON ((source_1_1."ID_Commande" = historique."ID_Commande")))
                     LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1_1."ID_DeviseFk")))) source_1) source
     LEFT JOIN logistique."T_BonCodeHistorique" h ON ((h."ID_Commande" = source."ID_Commande")));

--
-- Name: VIEW "V_CommandeOverview"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CommandeOverview" IS 'Projection commune des bons ou lignes avec nature BE/BS/CMD, montants exacts et correspondance historique de code issue du journal06. Les identifiants et écritures métier restent inchangés.';

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

COMMENT ON COLUMN logistique."V_CommandeOverview"."CodeCmd" IS 'Code courant BE-/BS-/CMD- ; les références documentaires émises se résolvent par fn_code_bon_a_date.';

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

COMMENT ON COLUMN logistique."V_CommandeOverview"."EtatPaiement" IS 'État de paiement partagé avec V_Commande ; CMD reste Sans facturation.';

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
-- Name: COLUMN "V_CommandeOverview"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';

--
-- Name: COLUMN "V_CommandeOverview"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_CommandeOverview"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_CommandeOverview"."NatureBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."NatureBon" IS 'entree ou sortie pour un document physique ; commande pour CMD explicite du référentiel ; NULL si un ancien type est inconnu.';

--
-- Name: COLUMN "V_CommandeOverview"."AncienCodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."AncienCodeCmd" IS 'Code exact avant la nomenclature06 si ce bon a été renommé ; issu du journal immuable, sans réécrire le document ni les écritures émises.';

--
-- Name: COLUMN "V_CommandeOverview"."RenumeroteLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandeOverview"."RenumeroteLe" IS 'Instant de la reprise06 de ce bon ; absent pour un code déjà canonique ou une création ultérieure.';

--
-- Name: V_CommandesSansDetails; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CommandesSansDetails" AS
 SELECT s."ID_Commande",
    s."DateCmd",
    s."CodeCmd",
    s."ID_TypeCmdFk",
    s."AbrTypeCmd",
    s."TypeCmd",
    s."NomClientSaisi",
    s."ObsCmd",
    s."ID_DeviseFk",
    s."DeviseCode",
    s."DeviseLibelle",
    s."IdEntiteFk",
    s."ID_TiersFk",
    s."TiersNom",
    c."ID_DestinationFk",
    d.label AS "DestinationLibelle"
   FROM ((( SELECT source."ID_Commande",
            source."DateCmd",
            source."CodeCmd",
            source."ID_TypeCmdFk",
            source."AbrTypeCmd",
            source."TypeCmd",
            source."NomClientSaisi",
            source."ObsCmd",
            source."ID_DeviseFk",
            source."DeviseCode",
            source."DeviseLibelle",
            r."IdEntiteFk",
            r."ID_TiersFk",
            t."Nom" AS "TiersNom"
           FROM ((( SELECT historique."ID_Commande",
                    historique."DateCmd",
                    historique."CodeCmd",
                    historique."ID_TypeCmdFk",
                    historique."AbrTypeCmd",
                    historique."TypeCmd",
                    historique."NomClientSaisi",
                    historique."ObsCmd",
                    source_1."ID_DeviseFk",
                    logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
                    (devise."NomGenerique")::text AS "DeviseLibelle"
                   FROM ((( SELECT c_1."ID_Commande",
                            c_1."DateCmd",
                            c_1."CodeCmd",
                            c_1."ID_TypeCmdFk",
                            type_cmd."AbrGenerique" AS "AbrTypeCmd",
                            type_cmd."NomGenerique" AS "TypeCmd",
                            c_1."NomClientSaisi",
                            c_1."ObsCmd"
                           FROM ((logistique."T_Commande" c_1
                             LEFT JOIN logistique."T_CommandeDetail" d_1 ON ((d_1."ID_CmdFk" = c_1."ID_Commande")))
                             LEFT JOIN referentiel."T_Generique" type_cmd ON ((c_1."ID_TypeCmdFk" = type_cmd."ID_Generique")))
                          WHERE ((d_1."ID_CmdFk" IS NULL) AND ((COALESCE(c_1."CodeCmd", ''::character varying))::text <> ALL (ARRAY[('C_000E'::character varying)::text, ('C_000S'::character varying)::text])))) historique
                     LEFT JOIN logistique."T_Commande" source_1 ON ((source_1."ID_Commande" = historique."ID_Commande")))
                     LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
             LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source."ID_Commande")))
             LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")))) s
     JOIN logistique."T_Commande" c ON ((c."ID_Commande" = s."ID_Commande")))
     LEFT JOIN geolocalisation."V_DestinationLogistique" d ON ((d.id = c."ID_DestinationFk")));

--
-- Name: VIEW "V_CommandesSansDetails"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CommandesSansDetails" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

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

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."AbrTypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_CommandesSansDetails"."TypeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."TypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_CommandesSansDetails"."NomClientSaisi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."NomClientSaisi" IS 'Nom du client saisi librement sur la commande, distinct d’un rattachement par identifiant. Expression projetée : c."NomClientSaisi".';

--
-- Name: COLUMN "V_CommandesSansDetails"."ObsCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."ObsCmd" IS 'Observations enregistrées sur la commande. Expression projetée : c."ObsCmd".';

--
-- Name: COLUMN "V_CommandesSansDetails"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';

--
-- Name: COLUMN "V_CommandesSansDetails"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_CommandesSansDetails"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_CommandesSansDetails"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_CommandesSansDetails"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."ID_TiersFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_CommandesSansDetails"."TiersNom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."TiersNom" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_CommandesSansDetails"."ID_DestinationFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."ID_DestinationFk" IS 'Lieu référencé ou chemin géographique existant : ID_DestinationFk. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_CommandesSansDetails"."DestinationLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."DestinationLibelle" IS 'Lieu référencé ou chemin géographique existant : DestinationLibelle. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: V_ConsoMensuelleDevise; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_ConsoMensuelleDevise" AS
 SELECT "ID_ArticleFk" AS "ID_Article",
    "NomArticle",
    (date_trunc('month'::text, "DateMvt"))::date AS "Mois",
    sum(
        CASE
            WHEN ("SigneStock" = '-1'::integer) THEN COALESCE("QteMvt", (0)::numeric)
            ELSE (0)::numeric
        END) AS "ConsoMensuelle",
    (sum(
        CASE
            WHEN ("SigneStock" = '-1'::integer) THEN COALESCE("MontantMvt", (0)::numeric)
            ELSE (0)::numeric
        END))::numeric(14,2) AS "ValeurConsoMensuelle",
    "ID_DeviseFk",
    "DeviseCode",
    "DeviseLibelle",
    jsonb_build_array(jsonb_build_object('id', "ID_DeviseFk", 'code', "DeviseCode", 'label', "DeviseLibelle", 'value', ((sum(
        CASE
            WHEN ("SigneStock" = '-1'::integer) THEN COALESCE("MontantMvt", (0)::numeric)
            ELSE (0)::numeric
        END))::numeric(14,2))::text, 'count', count(*) FILTER (WHERE ("SigneStock" = '-1'::integer)))) AS "MontantsParDevise"
   FROM logistique."V_MouvementStock" v
  WHERE ("DateMvt" IS NOT NULL)
  GROUP BY "ID_ArticleFk", "NomArticle", ((date_trunc('month'::text, "DateMvt"))::date), "ID_DeviseFk", "DeviseCode", "DeviseLibelle";

--
-- Name: VIEW "V_ConsoMensuelleDevise"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_ConsoMensuelleDevise" IS 'Consommation au grain article/mois/devise historique des mouvements ; source des filtres par devise, sans changement de quantité ni conversion.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."ID_Article" IS 'Article commun aux mouvements de consommation.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."NomArticle" IS 'Nom du catalogue article, sans filtrage métier supplémentaire.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."Mois"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."Mois" IS 'Premier jour du mois de DateMvt ; les dates absentes sont exclues.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."ConsoMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."ConsoMensuelle" IS 'Somme des quantités de sortie, dans l’unité de stock de cet article.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."ValeurConsoMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."ValeurConsoMensuelle" IS 'Valeur des sorties dans la devise indiquée ; NULL si plusieurs devises au grain article/mois. Aucune conversion.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."ID_DeviseFk" IS 'Référence de devise des mouvements du mois ; aucune conversion.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_ConsoMensuelleDevise"."MontantsParDevise"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."MontantsParDevise" IS 'Tableau JSON de {id,code,label,value,count} ; value est une chaîne décimale exacte, count le nombre de mouvements de sortie. Ne jamais sommer les devises.';

--
-- Name: V_ConsoMensuelle; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_ConsoMensuelle" AS
 SELECT source."ID_Article",
    source."NomArticle",
    source."Mois",
    source."ConsoMensuelle",
    source."ValeurConsoMensuelle",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    source."MontantsParDevise",
    r."IdEntiteFk"
   FROM (( SELECT d."ID_Article",
            d."NomArticle",
            d."Mois",
            sum(d."ConsoMensuelle") AS "ConsoMensuelle",
            (
                CASE
                    WHEN (count(*) = 1) THEN min(d."ValeurConsoMensuelle")
                    ELSE NULL::numeric
                END)::numeric(14,2) AS "ValeurConsoMensuelle",
                CASE
                    WHEN (count(*) = 1) THEN min(d."ID_DeviseFk")
                    ELSE NULL::integer
                END AS "ID_DeviseFk",
                CASE
                    WHEN (count(*) = 1) THEN min(d."DeviseCode")
                    ELSE NULL::text
                END AS "DeviseCode",
                CASE
                    WHEN (count(*) = 1) THEN min(d."DeviseLibelle")
                    ELSE NULL::text
                END AS "DeviseLibelle",
            jsonb_agg((d."MontantsParDevise" -> 0) ORDER BY d."DeviseCode", d."ID_DeviseFk") AS "MontantsParDevise"
           FROM logistique."V_ConsoMensuelleDevise" d
          GROUP BY d."ID_Article", d."NomArticle", d."Mois") source
     LEFT JOIN logistique."T_Article" r ON ((r."ID_Article" = source."ID_Article")));

--
-- Name: VIEW "V_ConsoMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_ConsoMensuelle" IS 'Consommation au grain historique article/mois : quantités toutes devises, valeur scalaire NULL si plusieurs devises ; répartition exacte dans MontantsParDevise. Un filtre devise doit employer V_ConsoMensuelleDevise.';

--
-- Name: COLUMN "V_ConsoMensuelle"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ID_Article" IS 'Article commun aux mouvements de consommation.';

--
-- Name: COLUMN "V_ConsoMensuelle"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."NomArticle" IS 'Nom du catalogue article, sans filtrage métier supplémentaire.';

--
-- Name: COLUMN "V_ConsoMensuelle"."Mois"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."Mois" IS 'Premier jour du mois de DateMvt ; les dates absentes sont exclues.';

--
-- Name: COLUMN "V_ConsoMensuelle"."ConsoMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ConsoMensuelle" IS 'Somme des quantités de sortie, dans l’unité de stock de cet article.';

--
-- Name: COLUMN "V_ConsoMensuelle"."ValeurConsoMensuelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ValeurConsoMensuelle" IS 'Valeur des sorties dans la devise indiquée ; NULL si plusieurs devises au grain article/mois. Aucune conversion.';

--
-- Name: COLUMN "V_ConsoMensuelle"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ID_DeviseFk" IS 'Référence de devise des sorties historiques ; NULL scalaire si plusieurs devises dans le mois ; aucune conversion.';

--
-- Name: COLUMN "V_ConsoMensuelle"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_ConsoMensuelle"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_ConsoMensuelle"."MontantsParDevise"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."MontantsParDevise" IS 'Tableau JSON de {id,code,label,value,count} ; value est une chaîne décimale exacte, count le nombre de mouvements de sortie. Ne jamais sommer les devises.';

--
-- Name: COLUMN "V_ConsoMensuelle"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ConsoMensuelle"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: V_CoutMouvement; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CoutMouvement" AS
 SELECT f."ID_Mvt",
    k."ID_ArticleFk",
    k."ID_DeviseFk",
    a."IdEntiteFk",
    f."QteSignee",
    round(f."CoutUnitaire", 6) AS "CoutUnitaire",
    f."ValeurMouvement",
    f."StockApres",
    f."ValeurApres",
    f."OrigineCout",
    f."EtatValorisation",
    m."DateMvt",
    m."ID_cmdFk",
    c."CodeCmd",
    g."AbrGenerique" AS "DeviseCode"
   FROM (((((( SELECT DISTINCT "T_Mouvement"."ID_ArticleFk",
            "T_Mouvement"."ID_DeviseFk"
           FROM logistique."T_Mouvement"
          WHERE ("T_Mouvement"."ID_DeviseFk" IS NOT NULL)) k
     JOIN logistique."T_Article" a ON ((a."ID_Article" = k."ID_ArticleFk")))
     CROSS JOIN LATERAL logistique.fn_cout_mouvements(k."ID_ArticleFk", k."ID_DeviseFk") f("ID_Mvt", "ID_ArticleFk", "ID_DeviseFk", "IdEntiteFk", "QteSignee", "CoutUnitaire", "ValeurMouvement", "StockApres", "ValeurApres", "OrigineCout", "EtatValorisation"))
     JOIN logistique."T_Mouvement" m ON ((m."ID_Mvt" = f."ID_Mvt")))
     LEFT JOIN logistique."T_Commande" c ON ((c."ID_Commande" = m."ID_cmdFk")))
     JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = k."ID_DeviseFk")));

--
-- Name: VIEW "V_CoutMouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CoutMouvement" IS 'Justification commune des coûts et valeurs du journal, distincte des prix commerciaux. Une ligne par mouvement avec devise et propriétaire explicites ; les valeurs avant un arrêté sans coût prouvé restent vides.';

--
-- Name: COLUMN "V_CoutMouvement"."ID_Mvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."ID_Mvt" IS 'ID_Mvt : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."ID_ArticleFk" IS 'ID_ArticleFk : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."ID_DeviseFk" IS 'ID_DeviseFk : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."IdEntiteFk" IS 'IdEntiteFk : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."QteSignee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."QteSignee" IS 'QteSignee : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."CoutUnitaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."CoutUnitaire" IS 'CoutUnitaire : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."ValeurMouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."ValeurMouvement" IS 'ValeurMouvement : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."StockApres"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."StockApres" IS 'StockApres : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."ValeurApres"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."ValeurApres" IS 'ValeurApres : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."OrigineCout"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."OrigineCout" IS 'OrigineCout : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."EtatValorisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."EtatValorisation" IS 'EtatValorisation : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."DateMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."DateMvt" IS 'DateMvt : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."ID_cmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."ID_cmdFk" IS 'ID_cmdFk : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."CodeCmd" IS 'CodeCmd : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_CoutMouvement"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CoutMouvement"."DeviseCode" IS 'DeviseCode : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: V_CouvertureStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_CouvertureStock" AS
 SELECT source."ID_Article",
    source."CodeArticleInterne",
    source."NomArticle",
    source."AbrUnite",
    source."StockActuel",
    source."Conso6Mois",
    source."ConsoMoyMensuelle",
    source."CouvertureMois",
    source."EtatCouverture",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk"
   FROM (( SELECT historique."ID_Article",
            historique."CodeArticleInterne",
            historique."NomArticle",
            historique."AbrUnite",
            historique."StockActuel",
            historique."Conso6Mois",
            historique."ConsoMoyMensuelle",
            historique."CouvertureMois",
            historique."EtatCouverture",
            source_1."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( WITH conso AS (
                         SELECT v."ID_ArticleFk",
                            sum(
                                CASE
                                    WHEN (v."SigneStock" = '-1'::integer) THEN COALESCE(v."QteMvt", (0)::numeric)
                                    ELSE (0)::numeric
                                END) AS conso_6m
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
                     LEFT JOIN conso ON ((conso."ID_ArticleFk" = a."ID_Article")))) historique
             LEFT JOIN logistique."T_Article" source_1 ON ((source_1."ID_Article" = historique."ID_Article")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Article" r ON ((r."ID_Article" = source."ID_Article")));

--
-- Name: VIEW "V_CouvertureStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_CouvertureStock" IS 'Couverture au grain article : sorties depuis CURRENT_DATE moins six mois et avant le lendemain de CURRENT_DATE. Moyenne divisée par six puis stock/moyenne ; les jours futurs sont exclus, NULL sans consommation. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';

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
-- Name: COLUMN "V_CouvertureStock"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';

--
-- Name: COLUMN "V_CouvertureStock"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_CouvertureStock"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_CouvertureStock"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_CouvertureStock"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: V_DossierSuivi; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_DossierSuivi" AS
 SELECT d."ID_DossierSuivi",
    d."ID_UserFk",
    d."IdEntiteFk",
    d."ID_CategorieDossierSuiviFk",
    d."Nom",
    d."Description",
    d."Couleur",
    d."TypeObjet",
    d."Mode",
    d."Regles",
    d."Actif",
    d."Version",
    d."CreeLe",
    d."ModifieLe",
    c."Nom" AS "CategorieDossier"
   FROM (logistique."T_DossierSuivi" d
     LEFT JOIN logistique."T_CategorieDossierSuivi" c ON ((c."ID_CategorieDossierSuivi" = d."ID_CategorieDossierSuiviFk")));

--
-- Name: VIEW "V_DossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_DossierSuivi" IS 'Projection de lecture du classement des articles, à filtrer par propriétaire et organisation.';

--
-- Name: COLUMN "V_DossierSuivi"."ID_DossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."ID_DossierSuivi" IS 'Identifiant permanent du dossier ; indépendant de son libellé.';

--
-- Name: COLUMN "V_DossierSuivi"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';

--
-- Name: COLUMN "V_DossierSuivi"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_DossierSuivi"."ID_CategorieDossierSuiviFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."ID_CategorieDossierSuiviFk" IS 'Catégorie de classement du même propriétaire et du même périmètre.';

--
-- Name: COLUMN "V_DossierSuivi"."Nom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."Nom" IS 'Libellé métier du dossier ou de sa catégorie.';

--
-- Name: COLUMN "V_DossierSuivi"."Description"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."Description" IS 'Description facultative du suivi.';

--
-- Name: COLUMN "V_DossierSuivi"."Couleur"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';

--
-- Name: COLUMN "V_DossierSuivi"."TypeObjet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."TypeObjet" IS 'Type immuable du dossier : article, bon ou facture. Une facture correspond au bon portant sa référence de facture dans le modèle actuel.';

--
-- Name: COLUMN "V_DossierSuivi"."Mode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."Mode" IS 'manuel pour les rattachements explicites, automatique pour une sélection dynamique.';

--
-- Name: COLUMN "V_DossierSuivi"."Regles"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."Regles" IS 'Critères JSON autorisés selon TypeObjet, interprétés par le serveur ; aucun fragment SQL utilisateur.';

--
-- Name: COLUMN "V_DossierSuivi"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."Actif" IS 'État actif ; false conserve le classement archivé.';

--
-- Name: COLUMN "V_DossierSuivi"."Version"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."Version" IS 'Version de concurrence optimiste des métadonnées du dossier.';

--
-- Name: COLUMN "V_DossierSuivi"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."CreeLe" IS 'Instant de création.';

--
-- Name: COLUMN "V_DossierSuivi"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';

--
-- Name: COLUMN "V_DossierSuivi"."CategorieDossier"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuivi"."CategorieDossier" IS 'Libellé de la catégorie du dossier, sans modifier la catégorie de l’article.';

--
-- Name: V_DossierSuiviMembre; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_DossierSuiviMembre" AS
 SELECT m."ID_Membre",
    m."ID_DossierSuiviFk",
    m."ID_ArticleFk",
    m."ID_CommandeFk",
    d."TypeObjet",
    m."Actif",
    m."AjouteLe",
    m."ModifieLe",
    d."ID_UserFk",
    d."IdEntiteFk",
    d."Nom" AS "NomDossier",
    d."Couleur"
   FROM (logistique."T_DossierSuiviMembre" m
     JOIN logistique."T_DossierSuivi" d ON ((d."ID_DossierSuivi" = m."ID_DossierSuiviFk")))
  WHERE ((d."Mode")::text = 'manuel'::text);

--
-- Name: VIEW "V_DossierSuiviMembre"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_DossierSuiviMembre" IS 'Projection de lecture du classement des articles, à filtrer par propriétaire et organisation.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."ID_Membre"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_Membre" IS 'Identifiant permanent du rattachement ; unicité par dossier et objet classé.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."ID_DossierSuiviFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_DossierSuiviFk" IS 'Dossier manuel actif du rattachement.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_ArticleFk" IS 'Article classé ; clé de la vue et de la table article existantes.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."ID_CommandeFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_CommandeFk" IS 'Bon classé, ou bon portant la facture classée ; exclusif de ID_ArticleFk. La facture reste soumise à son existence actuelle.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."TypeObjet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."TypeObjet" IS 'Type immuable du dossier : article, bon ou facture. Une facture correspond au bon portant sa référence de facture dans le modèle actuel.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."Actif" IS 'État actif ; false conserve le classement archivé.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."AjouteLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."AjouteLe" IS 'Date du premier rattachement manuel ; conservée lors d’une réactivation.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."NomDossier"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."NomDossier" IS 'Libellé du dossier manuel associé.';

--
-- Name: COLUMN "V_DossierSuiviMembre"."Couleur"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';

--
-- Name: V_FactureLigne; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_FactureLigne" AS
 SELECT v."ID_FactureLigne",
    v."ID_FactureFk",
    v."ID_CmdFk",
    v."ID_ArticleFk",
    v."NomArticle",
    v."CodeArticleInterne",
    v."Unite",
    v."QteSortie",
    v."QteRetourAvantFacture",
    v."QteFacturee",
    v."PUFacture",
    v."MontantLigne",
    v."ID_CommandeFk",
    v."CodeFacture",
    v."ID_DeviseFk",
    v."DeviseCode",
    v."DeviseLibelle",
    f."TauxTVA",
    l."MontantTVA",
    l."MontantTTC"
   FROM (( SELECT l_1."ID_FactureLigne",
            l_1."ID_FactureFk",
            l_1."ID_CmdFk",
            l_1."ID_ArticleFk",
            l_1."NomArticle",
            l_1."CodeArticleInterne",
            l_1."Unite",
            l_1."QteSortie",
            l_1."QteRetourAvantFacture",
            l_1."QteFacturee",
            l_1."PUFacture",
            l_1."MontantLigne",
            f_1."ID_CommandeFk",
            f_1."CodeFacture",
            f_1."ID_DeviseFk",
            f_1."DeviseCode",
            f_1."DeviseLibelle"
           FROM (logistique."T_FactureLigne" l_1
             JOIN logistique."T_Facture" f_1 ON ((f_1."ID_Facture" = l_1."ID_FactureFk")))) v
     JOIN (logistique."T_FactureLigne" l
     JOIN logistique."T_Facture" f ON ((f."ID_Facture" = l."ID_FactureFk"))) ON ((l."ID_FactureLigne" = v."ID_FactureLigne")));

--
-- Name: VIEW "V_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_FactureLigne" IS 'Lignes historiques HT/TVA/TTC d’une facture, avec désignations, quantités nettes et devise figées.';

--
-- Name: COLUMN "V_FactureLigne"."ID_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."ID_FactureLigne" IS 'Projection financière : ID_FactureLigne ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."ID_FactureFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."ID_FactureFk" IS 'Projection financière : ID_FactureFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."ID_CmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."ID_CmdFk" IS 'Projection financière : ID_CmdFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."ID_ArticleFk" IS 'Projection financière : ID_ArticleFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."NomArticle" IS 'Projection financière : NomArticle ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."CodeArticleInterne" IS 'Projection financière : CodeArticleInterne ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."Unite" IS 'Projection financière : Unite ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."QteSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."QteSortie" IS 'Projection financière : QteSortie ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."QteRetourAvantFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."QteRetourAvantFacture" IS 'Projection financière : QteRetourAvantFacture ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."QteFacturee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."QteFacturee" IS 'Projection financière : QteFacturee ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."PUFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."PUFacture" IS 'Projection financière : PUFacture ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."MontantLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."MontantLigne" IS 'Projection financière : MontantLigne ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."ID_CommandeFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."ID_CommandeFk" IS 'Projection financière : ID_CommandeFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."CodeFacture" IS 'Projection financière : CodeFacture ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."ID_DeviseFk" IS 'Projection financière : ID_DeviseFk ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."DeviseCode" IS 'Projection financière : DeviseCode ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."DeviseLibelle" IS 'Projection financière : DeviseLibelle ; snapshot émis ou agrégat exhaustif de ses règlements/retours.';

--
-- Name: COLUMN "V_FactureLigne"."TauxTVA"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."TauxTVA" IS 'Taux de la facture d’origine, conservé pour réimpression et avoir.';

--
-- Name: COLUMN "V_FactureLigne"."MontantTVA"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."MontantTVA" IS 'Taxe figée de cette ligne.';

--
-- Name: COLUMN "V_FactureLigne"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_FactureLigne"."MontantTTC" IS 'Montant HT de ligne plus sa taxe.';

--
-- Name: V_Immobilisation; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Immobilisation" AS
 SELECT i."ID_Immobilisation",
    i."IdEntiteFk",
    i."CodeImmobilisation",
    i."NomImmobilisation",
    i."Reference",
    i."Caracteristiques",
    i."SuiviIndividuel",
    i."Quantite",
    i."PrixUnitaire",
    i."ID_DeviseFk",
    i."ID_CategorieFk",
    i."ID_EtatFk",
    i."ID_ResponsableFk",
    i."ID_ServiceFk",
    i."ID_LocalisationFk",
    i."LocalisationComplement",
    i."DateEntree",
    i."DateAcquisition",
    i."NumeroSerie",
    i."Observations",
    i."Actif",
    i."CreeLe",
    i."ModifieLe",
    i."CreeParUserFk",
    i."ModifieParUserFk",
    e."NomEntite",
    c."NomGenerique" AS "CategorieMateriel",
    s."NomGenerique" AS "EtatMateriel",
    service."NomGenerique" AS "Service",
    NULLIF(concat_ws(' '::text, u."PrenomUser", u."NomUser"), ''::text) AS "Responsable",
    d."AbrGenerique" AS "DeviseCode",
    d."NomGenerique" AS "DeviseLibelle",
        CASE
            WHEN (i."PrixUnitaire" IS NULL) THEN NULL::numeric
            ELSE round((i."Quantite" * i."PrixUnitaire"), 2)
        END AS "ValeurAcquisition",
    NULLIF(concat_ws(' · '::text, NULLIF(l."AdresseDetaillee", ''::text), NULLIF((l."NomNiveau_5")::text, ''::text), NULLIF((l."NomNiveau_4")::text, ''::text), NULLIF((l."NomNiveau_3")::text, ''::text)), ''::text) AS "Localisation",
    (i.xmin)::text AS _version
   FROM (((((((logistique."T_Immobilisation" i
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = i."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" c ON ((c."ID_Generique" = i."ID_CategorieFk")))
     LEFT JOIN referentiel."T_Generique" s ON ((s."ID_Generique" = i."ID_EtatFk")))
     LEFT JOIN referentiel."T_Generique" service ON ((service."ID_Generique" = i."ID_ServiceFk")))
     LEFT JOIN referentiel."T_Generique" d ON ((d."ID_Generique" = i."ID_DeviseFk")))
     LEFT JOIN systeme."T_Utilisateurs" u ON (((u."IdUser" = i."ID_ResponsableFk") AND (u."IdEntiteFk" = i."IdEntiteFk"))))
     LEFT JOIN systeme."V_Entite_Localisation_Detail" l ON (((l."IdEntiteLocalisation" = i."ID_LocalisationFk") AND (l."IdEntite" = i."IdEntiteFk"))));

--
-- Name: VIEW "V_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Immobilisation" IS 'Registre de patrimoine au grain un bien/groupe homogène, avec LEFT JOIN conservant les références optionnelles et contrôle du propriétaire des lieux/responsables. Valeur d’acquisition indicative exacte, NULL si coût inconnu ; aucun montant comptable amorti ou stock réservé. Filtrage par entreprise imposé au serveur.';

--
-- Name: COLUMN "V_Immobilisation"."ID_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ID_Immobilisation" IS 'Identifiant technique stable du bien ; attribué par PostgreSQL et jamais réutilisé.';

--
-- Name: COLUMN "V_Immobilisation"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."IdEntiteFk" IS 'Entreprise propriétaire durable, obligatoire et immuable.';

--
-- Name: COLUMN "V_Immobilisation"."CodeImmobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."CodeImmobilisation" IS 'Code IMMO-identifiant attribué par trigger ; unique et immuable.';

--
-- Name: COLUMN "V_Immobilisation"."NomImmobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."NomImmobilisation" IS 'Désignation du bien, maximum200 caractères, sans contrôle ni espace extérieur.';

--
-- Name: COLUMN "V_Immobilisation"."Reference"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."Reference" IS 'Référence libre facultative du modèle ou du catalogue, maximum255 caractères.';

--
-- Name: COLUMN "V_Immobilisation"."Caracteristiques"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."Caracteristiques" IS 'Caractéristiques communes du bien ou du groupe homogène, maximum4000 caractères, retours de ligne autorisés.';

--
-- Name: COLUMN "V_Immobilisation"."SuiviIndividuel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."SuiviIndividuel" IS 'true par défaut pour une fiche par équipement ; false explicite pour un groupe homogène partageant caractéristiques, état et affectation.';

--
-- Name: COLUMN "V_Immobilisation"."Quantite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."Quantite" IS 'Nombre entier exact de biens, de1 à18 chiffres ; aucun arrondi silencieux des fractions. Un suivi individuel ou numéro de série impose1.';

--
-- Name: COLUMN "V_Immobilisation"."PrixUnitaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."PrixUnitaire" IS 'Prix d’acquisition unitaire indicatif à2 décimales, non négatif ; NULL signifie inconnu et ne vaut jamais zéro.';

--
-- Name: COLUMN "V_Immobilisation"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ID_DeviseFk" IS 'Devise du référentiel ; obligatoire dès que le prix est renseigné, sans conversion automatique.';

--
-- Name: COLUMN "V_Immobilisation"."ID_CategorieFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ID_CategorieFk" IS 'Type de matériel depuis le référentiel et les correspondances configurées pour cette entreprise.';

--
-- Name: COLUMN "V_Immobilisation"."ID_EtatFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ID_EtatFk" IS 'État facultatif issu de la famille configurée ; aucune présomption de bon état.';

--
-- Name: COLUMN "V_Immobilisation"."ID_ResponsableFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ID_ResponsableFk" IS 'Compte responsable de la même entreprise ; nouvelle affectation réservée aux comptes actifs dont les dates d’emploi permettent l’affectation.';

--
-- Name: COLUMN "V_Immobilisation"."ID_ServiceFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ID_ServiceFk" IS 'Service explicite du bien, issu du référentiel ; indépendant de l’évolution du service professionnel de son responsable.';

--
-- Name: COLUMN "V_Immobilisation"."ID_LocalisationFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ID_LocalisationFk" IS 'Lieu d’affectation appartenant à la même entreprise, sans lien texte ou égalité d’identifiants d’une autre table.';

--
-- Name: COLUMN "V_Immobilisation"."LocalisationComplement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."LocalisationComplement" IS 'Salle, bureau ou précision facultative de l’affectation, maximum255 caractères.';

--
-- Name: COLUMN "V_Immobilisation"."DateEntree"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."DateEntree" IS 'Date et heure d’entrée du bien dans le registre ; distincte de la date d’achat et des dates techniques.';

--
-- Name: COLUMN "V_Immobilisation"."DateAcquisition"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."DateAcquisition" IS 'Date d’acquisition facultative ; aucune date inventée si inconnue.';

--
-- Name: COLUMN "V_Immobilisation"."NumeroSerie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."NumeroSerie" IS 'Numéro de série facultatif, maximum255 caractères ; sa présence impose une fiche pour un seul bien.';

--
-- Name: COLUMN "V_Immobilisation"."Observations"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."Observations" IS 'Note complémentaire facultative, maximum4000 caractères, retours de ligne autorisés.';

--
-- Name: COLUMN "V_Immobilisation"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."Actif" IS 'true si le bien figure dans le registre actif ; false archive sa fiche sans effacer les affectations ni l’historique.';

--
-- Name: COLUMN "V_Immobilisation"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."CreeLe" IS 'Horodatage technique PostgreSQL de création, immuable.';

--
-- Name: COLUMN "V_Immobilisation"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ModifieLe" IS 'Horodatage technique PostgreSQL de la dernière écriture.';

--
-- Name: COLUMN "V_Immobilisation"."CreeParUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."CreeParUserFk" IS 'Auteur actif prouvé par le contexte transactionnel à la création, immuable.';

--
-- Name: COLUMN "V_Immobilisation"."ModifieParUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ModifieParUserFk" IS 'Auteur actif prouvé de la dernière écriture.';

--
-- Name: COLUMN "V_Immobilisation"."NomEntite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."NomEntite" IS 'Libellé courant NomEntite joint depuis son référentiel ou son propriétaire, sans calcul en frontend.';

--
-- Name: COLUMN "V_Immobilisation"."CategorieMateriel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."CategorieMateriel" IS 'Libellé courant CategorieMateriel joint depuis son référentiel ou son propriétaire, sans calcul en frontend.';

--
-- Name: COLUMN "V_Immobilisation"."EtatMateriel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."EtatMateriel" IS 'Libellé courant EtatMateriel joint depuis son référentiel ou son propriétaire, sans calcul en frontend.';

--
-- Name: COLUMN "V_Immobilisation"."Service"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."Service" IS 'Libellé courant Service joint depuis son référentiel ou son propriétaire, sans calcul en frontend.';

--
-- Name: COLUMN "V_Immobilisation"."Responsable"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."Responsable" IS 'Libellé courant Responsable joint depuis son référentiel ou son propriétaire, sans calcul en frontend.';

--
-- Name: COLUMN "V_Immobilisation"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."DeviseCode" IS 'Libellé courant DeviseCode joint depuis son référentiel ou son propriétaire, sans calcul en frontend.';

--
-- Name: COLUMN "V_Immobilisation"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."DeviseLibelle" IS 'Libellé courant DeviseLibelle joint depuis son référentiel ou son propriétaire, sans calcul en frontend.';

--
-- Name: COLUMN "V_Immobilisation"."ValeurAcquisition"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."ValeurAcquisition" IS 'Quantité entière multipliée par prix unitaire, arrondi monétaire à2 décimales ; NULL si prix inconnu, sans calcul d’amortissement.';

--
-- Name: COLUMN "V_Immobilisation"."Localisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"."Localisation" IS 'Adresse et niveaux géographiques du lieu lié, avec propriétaire vérifié ; aucune ligne supprimée par un champ optionnel absent.';

--
-- Name: COLUMN "V_Immobilisation"._version; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Immobilisation"._version IS 'Révision technique opaque xmin pour refuser les modifications concurrentes périmées.';

--
-- Name: V_Inventaire; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Inventaire" AS
SELECT
    NULL::bigint AS "ID_Inventaire",
    NULL::integer AS "IdEntiteFk",
    NULL::integer AS "ID_UserFk",
    NULL::timestamp with time zone AS "DateInventaire",
    NULL::text AS "Motif",
    NULL::text AS "Etat",
    NULL::bigint AS "Version",
    NULL::timestamp with time zone AS "CreeLe",
    NULL::timestamp with time zone AS "ModifieLe",
    NULL::timestamp with time zone AS "ValideLe",
    NULL::integer AS "ID_ValidateurFk",
    NULL::uuid AS "ValidationRequest",
    NULL::text AS "ValidationHash",
    NULL::text AS "CodeInventaire",
    NULL::bigint AS "NbArticles",
    NULL::bigint AS "NbEcarts",
    NULL::timestamp with time zone AS "AnnuleLe",
    NULL::integer AS "ID_AnnulateurFk",
    NULL::text AS "MotifAnnulation",
    NULL::uuid AS "AnnulationRequest",
    NULL::text AS "AnnulationHash";

--
-- Name: VIEW "V_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Inventaire" IS 'Registre des comptages, validations et annulations tracées par entreprise.';

--
-- Name: COLUMN "V_Inventaire"."ID_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."ID_Inventaire" IS 'Donnée ID_Inventaire de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."IdEntiteFk" IS 'Entreprise propriétaire stable ; ne découle jamais du rattachement actuel de l’auteur.';

--
-- Name: COLUMN "V_Inventaire"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."ID_UserFk" IS 'Donnée ID_UserFk de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."DateInventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."DateInventaire" IS 'Donnée DateInventaire de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."Motif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."Motif" IS 'Donnée Motif de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."Etat"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."Etat" IS 'Donnée Etat de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."Version"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."Version" IS 'Version optimiste incrémentée à chaque modification, indépendante des variations de stock.';

--
-- Name: COLUMN "V_Inventaire"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."CreeLe" IS 'Donnée CreeLe de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."ModifieLe" IS 'Donnée ModifieLe de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."ValideLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."ValideLe" IS 'Donnée ValideLe de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."ID_ValidateurFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."ID_ValidateurFk" IS 'Donnée ID_ValidateurFk de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."ValidationRequest"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."ValidationRequest" IS 'Identifiant de demande idempotente de validation ; un rejeu identique conserve les mêmes bons.';

--
-- Name: COLUMN "V_Inventaire"."ValidationHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."ValidationHash" IS 'Donnée ValidationHash de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."CodeInventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."CodeInventaire" IS 'Donnée CodeInventaire de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."NbArticles"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."NbArticles" IS 'Donnée NbArticles de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."NbEcarts"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."NbEcarts" IS 'Donnée NbEcarts de V_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_Inventaire"."AnnuleLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."AnnuleLe" IS 'Date et heure de l’annulation de validation.';

--
-- Name: COLUMN "V_Inventaire"."ID_AnnulateurFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."ID_AnnulateurFk" IS 'Administrateur ayant annulé la validation.';

--
-- Name: COLUMN "V_Inventaire"."MotifAnnulation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."MotifAnnulation" IS 'Justification obligatoire conservée dans l’historique.';

--
-- Name: COLUMN "V_Inventaire"."AnnulationRequest"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."AnnulationRequest" IS 'Identifiant de demande empêchant le double traitement.';

--
-- Name: COLUMN "V_Inventaire"."AnnulationHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Inventaire"."AnnulationHash" IS 'Empreinte du contenu de la demande d’annulation.';

--
-- Name: V_PrecisionStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_PrecisionStock" AS
 SELECT p."ID_PrecisionStock",
    g."ID_Generique" AS "ID_UniteFk",
    g."NomGenerique" AS "Unite",
    g."AbrGenerique" AS "Abreviation",
    (COALESCE((p."DecimalesStock")::integer, 0))::smallint AS "DecimalesStock",
    p."ModifieLe",
    g."ValideGenerique" AS "ValideUnite"
   FROM (referentiel."T_Generique" g
     LEFT JOIN logistique."T_PrecisionStock" p ON ((p."ID_UniteFk" = g."ID_Generique")))
  WHERE (referentiel.fn_reference_champ_connue('logistique'::text, 'T_Article'::text, 'ID_UniteFk'::text, g."ID_Generique") OR referentiel.fn_reference_champ_connue('logistique'::text, 'T_PrecisionStock'::text, 'ID_UniteFk'::text, g."ID_Generique"));

--
-- Name: VIEW "V_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_PrecisionStock" IS 'Précision des unités déclarées ou utilisées ; défaut explicite zéro décimale, paramètres historiques conservés et aucune quantité transformée.';

--
-- Name: COLUMN "V_PrecisionStock"."ID_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PrecisionStock"."ID_PrecisionStock" IS 'Identité de la politique explicite, NULL si l’unité utilise encore le défaut entier.';

--
-- Name: COLUMN "V_PrecisionStock"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PrecisionStock"."ID_UniteFk" IS 'Identité unique de l’unité du référentiel ; clé logique de cette vue.';

--
-- Name: COLUMN "V_PrecisionStock"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PrecisionStock"."Unite" IS 'Libellé courant de l’unité du référentiel.';

--
-- Name: COLUMN "V_PrecisionStock"."Abreviation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PrecisionStock"."Abreviation" IS 'Abréviation courante de l’unité du référentiel.';

--
-- Name: COLUMN "V_PrecisionStock"."DecimalesStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PrecisionStock"."DecimalesStock" IS 'Précision appliquée : politique explicite de zéro à trois décimales, ou zéro en l’absence de politique.';

--
-- Name: COLUMN "V_PrecisionStock"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PrecisionStock"."ModifieLe" IS 'Date du réglage explicite ou de son initialisation ; NULL pour une unité encore sans politique.';

--
-- Name: COLUMN "V_PrecisionStock"."ValideUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PrecisionStock"."ValideUnite" IS 'Validité courante de la valeur Unité ; les unités inactives restent lisibles pour l’historique.';

--
-- Name: V_InventaireLigne; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_InventaireLigne" AS
 SELECT l."ID_InventaireFk",
    l."ID_ArticleFk",
    l."QteTheorique",
    l."QteComptee",
    l."PUCorrection",
    l."Lots",
    l."Justification",
    l."ID_CommandeCorrectionFk",
    (l."QteComptee" - l."QteTheorique") AS "Ecart",
    a."IdEntiteFk",
    a."NomArticle",
    a."CodeArticleInterne",
    a."ID_UniteFk",
    g."AbrGenerique" AS "Unite",
    a."QteArticle" AS "StockActuel",
    COALESCE((p."DecimalesStock")::integer, 0) AS "Decimales",
    c."CodeCmd" AS "CodeCorrection",
    l."ID_CommandeAnnulationFk",
    ca."CodeCmd" AS "CodeAnnulation"
   FROM (((((logistique."T_InventaireLigne" l
     JOIN logistique."T_Article" a ON ((a."ID_Article" = l."ID_ArticleFk")))
     LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = a."ID_UniteFk")))
     LEFT JOIN logistique."V_PrecisionStock" p ON ((p."ID_UniteFk" = a."ID_UniteFk")))
     LEFT JOIN logistique."T_Commande" c ON ((c."ID_Commande" = l."ID_CommandeCorrectionFk")))
     LEFT JOIN logistique."T_Commande" ca ON ((ca."ID_Commande" = l."ID_CommandeAnnulationFk")));

--
-- Name: VIEW "V_InventaireLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_InventaireLigne" IS 'Comptage, écart et bon correcteur au grain article/inventaire ; précision provenant de V_PrecisionStock, sans variation des colonnes historiques.';

--
-- Name: COLUMN "V_InventaireLigne"."ID_InventaireFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."ID_InventaireFk" IS 'Donnée ID_InventaireFk de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."ID_ArticleFk" IS 'Donnée ID_ArticleFk de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."QteTheorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."QteTheorique" IS 'Stock exact capturé lors de la préparation du comptage, contrôlé de nouveau sous verrou à la validation.';

--
-- Name: COLUMN "V_InventaireLigne"."QteComptee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."QteComptee" IS 'Quantité physique saisie explicitement ; zéro est un comptage, absence est refusée.';

--
-- Name: COLUMN "V_InventaireLigne"."PUCorrection"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."PUCorrection" IS 'Donnée PUCorrection de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."Lots"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."Lots" IS 'Ventilation JSON des seuls écarts : numéro, quantité exacte et péremption facultative ; aucun mouvement autonome.';

--
-- Name: COLUMN "V_InventaireLigne"."Justification"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."Justification" IS 'Donnée Justification de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."ID_CommandeCorrectionFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."ID_CommandeCorrectionFk" IS 'Donnée ID_CommandeCorrectionFk de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."Ecart"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."Ecart" IS 'Donnée Ecart de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."IdEntiteFk" IS 'Entreprise propriétaire stable ; ne découle jamais du rattachement actuel de l’auteur.';

--
-- Name: COLUMN "V_InventaireLigne"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."NomArticle" IS 'Donnée NomArticle de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."CodeArticleInterne" IS 'Donnée CodeArticleInterne de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."ID_UniteFk" IS 'Donnée ID_UniteFk de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."Unite" IS 'Donnée Unite de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."StockActuel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."StockActuel" IS 'Donnée StockActuel de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."Decimales"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."Decimales" IS 'Précision de comptage fournie par la politique logistique commune de l’unité ; zéro pour une unité non paramétrée.';

--
-- Name: COLUMN "V_InventaireLigne"."CodeCorrection"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."CodeCorrection" IS 'Donnée CodeCorrection de V_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "V_InventaireLigne"."ID_CommandeAnnulationFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."ID_CommandeAnnulationFk" IS 'Identifiant du bon compensateur de cette ligne.';

--
-- Name: COLUMN "V_InventaireLigne"."CodeAnnulation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_InventaireLigne"."CodeAnnulation" IS 'Code consultable du bon compensateur de cette ligne.';

--
-- Name: V_Mouvement; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Mouvement" AS
 SELECT source."DateHeureAutoMvt",
    source."DateMvt",
    source."ID_Mvt",
    source."ID_TypeMvtFk",
    source."TypeMvt",
    source."NomTypeMvt",
    source."ID_ArticleFk",
    source."CodeArticleInterne",
    source."NomArticle",
    source."ID_cmdFk",
    source."CodeCmd",
    source."DateCmd",
    source."QteMvt",
    source."PUMvt",
    source."SigneStock",
    source."QteMvtSigned",
    source."MontantMvt",
    source."OrigineMouvement",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk",
    r."ID_TiersFk",
    t."Nom" AS "TiersNom"
   FROM ((( SELECT historique."DateHeureAutoMvt",
            historique."DateMvt",
            historique."ID_Mvt",
            historique."ID_TypeMvtFk",
            historique."TypeMvt",
            historique."NomTypeMvt",
            historique."ID_ArticleFk",
            historique."CodeArticleInterne",
            historique."NomArticle",
            historique."ID_cmdFk",
            historique."CodeCmd",
            historique."DateCmd",
            historique."QteMvt",
            historique."PUMvt",
            historique."SigneStock",
            historique."QteMvtSigned",
            historique."MontantMvt",
            historique."OrigineMouvement",
            source_1."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( SELECT m."DateHeureAutoMvt",
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
                    COALESCE(m."QteMvt", (0)::numeric) AS "QteMvt",
                    (COALESCE(m."PUMvt", (0)::numeric))::numeric(12,2) AS "PUMvt",
                    COALESCE((logistique.fn_effet_type_bon(m."ID_TypeMvtFk"))::integer, 0) AS "SigneStock",
                    (COALESCE(m."QteMvt", (0)::numeric) * (COALESCE((logistique.fn_effet_type_bon(m."ID_TypeMvtFk"))::integer, 0))::numeric) AS "QteMvtSigned",
                    ((COALESCE(m."QteMvt", (0)::numeric) * COALESCE(m."PUMvt", (0)::numeric)))::numeric(14,2) AS "MontantMvt",
                        CASE
                            WHEN (m."ID_cmdFk" IS NULL) THEN 'Ajustement direct article'::text
                            ELSE 'Commande'::text
                        END AS "OrigineMouvement"
                   FROM (((logistique."T_Mouvement" m
                     LEFT JOIN logistique."T_Article" a ON ((m."ID_ArticleFk" = a."ID_Article")))
                     LEFT JOIN logistique."T_Commande" c ON ((m."ID_cmdFk" = c."ID_Commande")))
                     LEFT JOIN referentiel."T_Generique" g_typemvt ON ((m."ID_TypeMvtFk" = g_typemvt."ID_Generique")))) historique
             LEFT JOIN logistique."T_Mouvement" source_1 ON ((source_1."ID_Mvt" = historique."ID_Mvt")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source."ID_cmdFk")))
     LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")));

--
-- Name: VIEW "V_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Mouvement" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves. Le signe de stock est celui du type historique, calcule par fn_effet_type_bon, jamais par la categorie actuelle.';

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

COMMENT ON COLUMN logistique."V_Mouvement"."TypeMvt" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

--
-- Name: COLUMN "V_Mouvement"."NomTypeMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."NomTypeMvt" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

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

COMMENT ON COLUMN logistique."V_Mouvement"."SigneStock" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

--
-- Name: COLUMN "V_Mouvement"."QteMvtSigned"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."QteMvtSigned" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

--
-- Name: COLUMN "V_Mouvement"."MontantMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."MontantMvt" IS 'Quantité × prix unitaire historique du mouvement. Expression projetée : (COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric))::numeric(14,2) AS "MontantMvt".';

--
-- Name: COLUMN "V_Mouvement"."OrigineMouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."OrigineMouvement" IS 'Commande si ID_cmdFk est renseigné, sinon Ajustement direct article. Expression projetée : CASE WHEN m."ID_cmdFk" IS NULL THEN ''Ajustement direct article''::text ELSE ''Commande''::text END AS "OrigineMouvement".';

--
-- Name: COLUMN "V_Mouvement"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."ID_DeviseFk" IS 'Référence de devise du mouvement historique ; aucune conversion.';

--
-- Name: COLUMN "V_Mouvement"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_Mouvement"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_Mouvement"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Mouvement"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."ID_TiersFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Mouvement"."TiersNom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Mouvement"."TiersNom" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: V_MouvementLot; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_MouvementLot" AS
 SELECT l."ID_MvtFk",
    l."ID_LotArticleFk",
    l."ID_ArticleFk",
    l."NumeroLot",
    l."DatePeremptionLot",
    l."Quantite",
    l."DateMvt",
    l."ID_cmdFk",
    l."SigneStock",
    l."QuantiteSignee",
    l."NomArticle",
    l."CodeCmd",
    l."ID_DeviseFk",
    l."DeviseCode",
    l."DeviseLibelle",
    ml."MotifDerogationPeremption",
    ml."ID_DerogationUserFk",
    ml."DateDerogationPeremption"
   FROM (( SELECT historique."ID_MvtFk",
            historique."ID_LotArticleFk",
            historique."ID_ArticleFk",
            historique."NumeroLot",
            historique."DatePeremptionLot",
            historique."Quantite",
            historique."DateMvt",
            historique."ID_cmdFk",
            historique."SigneStock",
            historique."QuantiteSignee",
            historique."NomArticle",
            historique."CodeCmd",
            source."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( SELECT ml_1."ID_MvtFk",
                    ml_1."ID_LotArticleFk",
                    l_1."ID_ArticleFk",
                    l_1."NumeroLot",
                    l_1."DatePeremptionLot",
                    ml_1."Quantite",
                    m."DateMvt",
                    m."ID_cmdFk",
                    m."SigneStock",
                    (ml_1."Quantite" * (m."SigneStock")::numeric) AS "QuantiteSignee",
                    m."NomArticle",
                    m."CodeCmd"
                   FROM ((logistique."T_MouvementLot" ml_1
                     JOIN logistique."T_LotArticle" l_1 ON ((l_1."ID_LotArticle" = ml_1."ID_LotArticleFk")))
                     JOIN logistique."V_MouvementStock" m ON ((m."ID_Mvt" = ml_1."ID_MvtFk")))) historique
             LEFT JOIN logistique."T_Mouvement" source ON ((source."ID_Mvt" = historique."ID_MvtFk")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source."ID_DeviseFk")))) l
     JOIN logistique."T_MouvementLot" ml ON (((ml."ID_MvtFk" = l."ID_MvtFk") AND (ml."ID_LotArticleFk" = l."ID_LotArticleFk"))));

--
-- Name: VIEW "V_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_MouvementLot" IS 'Historique des ventilations avec motif, compte et date de la dérogation de péremption éventuelle ; aucun mouvement supplémentaire.';

--
-- Name: COLUMN "V_MouvementLot"."ID_MvtFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."ID_MvtFk" IS 'Conservation du stock : ID_MvtFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."ID_LotArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."ID_LotArticleFk" IS 'Conservation du stock : ID_LotArticleFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."ID_ArticleFk" IS 'Conservation du stock : ID_ArticleFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."NumeroLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."NumeroLot" IS 'Conservation du stock : NumeroLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."DatePeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."DatePeremptionLot" IS 'Conservation du stock : DatePeremptionLot, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."Quantite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."Quantite" IS 'Conservation du stock : Quantite, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."DateMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."DateMvt" IS 'Conservation du stock : DateMvt, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."ID_cmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."ID_cmdFk" IS 'Conservation du stock : ID_cmdFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."SigneStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."SigneStock" IS 'Conservation du stock : SigneStock, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."QuantiteSignee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."QuantiteSignee" IS 'Conservation du stock : QuantiteSignee, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."NomArticle" IS 'Conservation du stock : NomArticle, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."CodeCmd" IS 'Conservation du stock : CodeCmd, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."ID_DeviseFk" IS 'Conservation du stock : ID_DeviseFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."DeviseCode" IS 'Conservation du stock : DeviseCode, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."DeviseLibelle" IS 'Conservation du stock : DeviseLibelle, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."MotifDerogationPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."MotifDerogationPeremption" IS 'Conservation du stock : MotifDerogationPeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."ID_DerogationUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."ID_DerogationUserFk" IS 'Conservation du stock : ID_DerogationUserFk, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: COLUMN "V_MouvementLot"."DateDerogationPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_MouvementLot"."DateDerogationPeremption" IS 'Conservation du stock : DateDerogationPeremption, calculée dans le périmètre de l’article et de son entreprise.';

--
-- Name: V_OffreArticle; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_OffreArticle" AS
 SELECT a."ID_Article",
    a."NomArticle",
    a."RefArticle",
    a."PVArticle",
    a."ID_DeviseFk",
    logistique.fn_code_devise((d."AbrGenerique")::text) AS "DeviseCode",
    (d."NomGenerique")::text AS "DeviseLibelle",
    COALESCE(NULLIF((u."AbrGenerique")::text, ''::text), (u."NomGenerique")::text) AS "Unite",
        CASE
            WHEN (a."QteArticle" > (0)::numeric) THEN 'Stock déclaré'::text
            ELSE 'Stock nul déclaré'::text
        END AS "EtatDisponibilite",
    a."PhotoArticle",
    e."IdEntite",
    e."NomEntite",
    e."AdresseEntite",
    e."PhoneEntite",
    a."ID_CategorieArticleFk",
    COALESCE(NULLIF((c."AbrGenerique")::text, ''::text), (c."NomGenerique")::text) AS "CategorieArticle",
    a."ID_TypeArticleFk",
    COALESCE(NULLIF((t."AbrGenerique")::text, ''::text), (t."NomGenerique")::text) AS "TypeArticle"
   FROM (((((logistique."T_Article" a
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = a."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" d ON ((d."ID_Generique" = a."ID_DeviseFk")))
     LEFT JOIN referentiel."T_Generique" u ON ((u."ID_Generique" = a."ID_UniteFk")))
     LEFT JOIN referentiel."T_Generique" c ON ((c."ID_Generique" = a."ID_CategorieArticleFk")))
     LEFT JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = a."ID_TypeArticleFk")))
  WHERE ((a."VisibleCatalogue" IS TRUE) AND (a."ValideArticle" IS TRUE) AND (e."ValideEntite" IS TRUE));

--
-- Name: VIEW "V_OffreArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_OffreArticle" IS 'Offres locales volontairement publiées d’articles actifs et d’entreprises actives. Grain article local ; catégories et types proviennent des valeurs centrales déjà enregistrées, sans réécriture des anciennes FK. Exclut coût d’achat, quantités exactes, notes et auteur. Stock déclaré ne garantit ni disponibilité vendable ni fraîcheur. Les API conservent authentification, licences et permissions ; aucun classement implicite entre devises ou unités ni collecte de recherche.';

--
-- Name: COLUMN "V_OffreArticle"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."ID_Article" IS 'Identifiant de l’article local publié, clé du grain de l’offre ; ne constitue pas encore un produit normalisé entre entreprises.';

--
-- Name: COLUMN "V_OffreArticle"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."NomArticle" IS 'Désignation courante déclarée par l’entreprise propriétaire.';

--
-- Name: COLUMN "V_OffreArticle"."RefArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."RefArticle" IS 'Référence externe facultative de l’article publiée avec son choix individuel.';

--
-- Name: COLUMN "V_OffreArticle"."PVArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."PVArticle" IS 'Prix de vente déclaré, associé à la devise de la même ligne ; aucun coût d’achat n’est exposé.';

--
-- Name: COLUMN "V_OffreArticle"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."ID_DeviseFk" IS 'Identifiant de la devise centrale stockée sur l’article ; aucun taux ni conversion implicite.';

--
-- Name: COLUMN "V_OffreArticle"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."DeviseCode" IS 'Code monétaire normalisé par la fonction logistique existante à partir du référentiel.';

--
-- Name: COLUMN "V_OffreArticle"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."DeviseLibelle" IS 'Libellé courant de la devise centrale, sans valeur de remplacement inventée.';

--
-- Name: COLUMN "V_OffreArticle"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."Unite" IS 'Abréviation courante de l’unité centrale, ou son libellé si l’abréviation est absente.';

--
-- Name: COLUMN "V_OffreArticle"."EtatDisponibilite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."EtatDisponibilite" IS 'Indication prudente de stock déclaré positif ou nul ; ne garantit ni stock réellement vendable ni qualité/péremption des lots et ne fournit aucune date de fraîcheur fictive.';

--
-- Name: COLUMN "V_OffreArticle"."PhotoArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."PhotoArticle" IS 'Référence privée de la photo ; le service transforme la valeur en route contrôlée par cette même publication, jamais en chemin de téléchargement public.';

--
-- Name: COLUMN "V_OffreArticle"."IdEntite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."IdEntite" IS 'Identifiant durable de l’entreprise propriétaire de l’offre.';

--
-- Name: COLUMN "V_OffreArticle"."NomEntite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."NomEntite" IS 'Nom courant de l’entreprise propriétaire publié avec l’offre.';

--
-- Name: COLUMN "V_OffreArticle"."AdresseEntite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."AdresseEntite" IS 'Adresse de structure déclarée dans la fiche entreprise ; aucune localisation ne se déduit d’un compte utilisateur.';

--
-- Name: COLUMN "V_OffreArticle"."PhoneEntite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."PhoneEntite" IS 'Téléphone de structure déclaré, distinct des coordonnées personnelles de l’auteur.';

--
-- Name: V_PieceJustificative; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_PieceJustificative" AS
 SELECT "ID_Piece",
    "TypeObjet",
    "ID_Objet",
    "IdEntiteFk",
    "ID_UserFk",
    "NomFichier",
    "MimeType",
    "TailleOctets",
    "Sha256",
    "Archive",
    "CreeLe"
   FROM logistique."T_PieceJustificative";

--
-- Name: VIEW "V_PieceJustificative"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_PieceJustificative" IS 'Métadonnées des pièces privées, sans contenu binaire ; le service impose le périmètre du document.';

--
-- Name: COLUMN "V_PieceJustificative"."ID_Piece"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."ID_Piece" IS 'Champ documentaire ID_Piece du justificatif ou de son identité historique.';

--
-- Name: COLUMN "V_PieceJustificative"."TypeObjet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."TypeObjet" IS 'Champ documentaire TypeObjet du justificatif ou de son identité historique.';

--
-- Name: COLUMN "V_PieceJustificative"."ID_Objet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."ID_Objet" IS 'Champ documentaire ID_Objet du justificatif ou de son identité historique.';

--
-- Name: COLUMN "V_PieceJustificative"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."IdEntiteFk" IS 'Entreprise propriétaire du document, indépendante du rattachement actuel du créateur.';

--
-- Name: COLUMN "V_PieceJustificative"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."ID_UserFk" IS 'Champ documentaire ID_UserFk du justificatif ou de son identité historique.';

--
-- Name: COLUMN "V_PieceJustificative"."NomFichier"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."NomFichier" IS 'Champ documentaire NomFichier du justificatif ou de son identité historique.';

--
-- Name: COLUMN "V_PieceJustificative"."MimeType"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."MimeType" IS 'Champ documentaire MimeType du justificatif ou de son identité historique.';

--
-- Name: COLUMN "V_PieceJustificative"."TailleOctets"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."TailleOctets" IS 'Champ documentaire TailleOctets du justificatif ou de son identité historique.';

--
-- Name: COLUMN "V_PieceJustificative"."Sha256"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."Sha256" IS 'Empreinte du contenu binaire enregistré.';

--
-- Name: COLUMN "V_PieceJustificative"."Archive"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."Archive" IS 'Pièce retirée du parcours actif, contenu et historique conservés.';

--
-- Name: COLUMN "V_PieceJustificative"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_PieceJustificative"."CreeLe" IS 'Champ documentaire CreeLe du justificatif ou de son identité historique.';

--
-- Name: V_ProprietairesARevoir; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_ProprietairesARevoir" AS
 SELECT 'article'::text AS "TypeObjet",
    "T_Article"."ID_Article" AS "Identifiant"
   FROM logistique."T_Article"
  WHERE ("T_Article"."IdEntiteFk" IS NULL)
UNION ALL
 SELECT 'commande'::text AS "TypeObjet",
    "T_Commande"."ID_Commande" AS "Identifiant"
   FROM logistique."T_Commande"
  WHERE ("T_Commande"."IdEntiteFk" IS NULL);

--
-- Name: VIEW "V_ProprietairesARevoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_ProprietairesARevoir" IS 'Diagnostic de quarantaine des propriétaires historiques non démontrés ; réservé à la plateforme.';

--
-- Name: V_QuantitesBonUnite; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_QuantitesBonUnite" AS
 WITH par_unite AS (
         SELECT d."ID_CmdFk",
            a."ID_UniteFk",
            g."NomGenerique" AS "Unite",
            g."AbrGenerique" AS "AbrUnite",
            sum(d."QteCmdDetail") AS "Quantite"
           FROM ((logistique."T_CommandeDetail" d
             JOIN logistique."T_Article" a ON ((a."ID_Article" = d."ID_ArticleFk")))
             LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = a."ID_UniteFk")))
          GROUP BY d."ID_CmdFk", a."ID_UniteFk", g."NomGenerique", g."AbrGenerique"
        )
 SELECT "ID_CmdFk",
    (count(*))::integer AS "NombreUnites",
        CASE
            WHEN ((count(*) = 1) AND (count("ID_UniteFk") = 1)) THEN sum("Quantite")
            ELSE NULL::numeric
        END AS "QuantiteHomogene",
    jsonb_agg(jsonb_build_object('uniteId', "ID_UniteFk", 'unite', "Unite", 'code', "AbrUnite", 'quantite', ("Quantite")::text) ORDER BY "ID_UniteFk") AS "QuantitesParUnite"
   FROM par_unite
  GROUP BY "ID_CmdFk";

--
-- Name: VIEW "V_QuantitesBonUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_QuantitesBonUnite" IS 'Quantités d’un bon ventilées par unité réelle. Une quantité scalaire n’est fournie que pour une unité unique connue ; aucune addition de kg et pièces.';

--
-- Name: COLUMN "V_QuantitesBonUnite"."ID_CmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_QuantitesBonUnite"."ID_CmdFk" IS 'Bon dont les lignes sont ventilées par unité.';

--
-- Name: COLUMN "V_QuantitesBonUnite"."NombreUnites"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_QuantitesBonUnite"."NombreUnites" IS 'Nombre d’unités distinctes des lignes du bon, sans convertir.';

--
-- Name: COLUMN "V_QuantitesBonUnite"."QuantiteHomogene"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_QuantitesBonUnite"."QuantiteHomogene" IS 'Somme numérique uniquement si toutes les lignes utilisent la même unité connue ; NULL si hétérogène.';

--
-- Name: COLUMN "V_QuantitesBonUnite"."QuantitesParUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_QuantitesBonUnite"."QuantitesParUnite" IS 'Quantités exactes et libellés regroupés par unité pour affichage et export autonome.';

--
-- Name: V_RegistreLots; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_RegistreLots" AS
 SELECT l."ID_LotArticle",
    l."ID_ArticleFk",
    l."NumeroLot",
    l."DatePeremptionLot",
    l."Actif",
    l."CreeLe",
    l."StockLot",
    l."QuantiteEntree",
    l."QuantiteSortie",
    l."ID_DeviseFk",
    l."DeviseCode",
    l."DeviseLibelle",
    l."IdEntiteFk",
    l."NomArticle",
    l."ID_UniteFk",
    l."Unite",
    l."EtatPeremptionLot",
    l."EstPerime",
    l."EstProche",
    l."SeuilAlerteJours",
    l."BloquerLotsPerimes",
    a."CodeArticleInterne",
    a."RefArticle",
    a."PhotoArticle",
    a."ID_CategorieArticleFk",
    cat."NomGenerique" AS "CategorieArticle",
    a."ID_TypeArticleFk",
    typ."NomGenerique" AS "TypeArticle",
    a."ValideArticle",
    a."QteArticle" AS "StockArticle",
    l."Unite" AS "AbrUnite",
    e."NomEntite",
        CASE
            WHEN (l."StockLot" < (0)::numeric) THEN 'Stock négatif'::text
            WHEN (l."StockLot" = (0)::numeric) THEN 'Épuisé'::text
            ELSE 'Disponible'::text
        END AS "EtatStockLot"
   FROM ((((logistique."V_LotDisponibilite" l
     JOIN logistique."T_Article" a ON ((a."ID_Article" = l."ID_ArticleFk")))
     LEFT JOIN referentiel."T_Generique" cat ON ((cat."ID_Generique" = a."ID_CategorieArticleFk")))
     LEFT JOIN referentiel."T_Generique" typ ON ((typ."ID_Generique" = a."ID_TypeArticleFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = l."IdEntiteFk")));

--
-- Name: VIEW "V_RegistreLots"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_RegistreLots" IS 'Registre de tous les lots, y compris épuisés ou archivés. Solde réel, péremption en date métier Kinshasa, unité de stock et propriétaire durable de l’article. Source commune écran, fiche et export ; aucun effet de stock.';

--
-- Name: COLUMN "V_RegistreLots"."ID_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."ID_LotArticle" IS 'Identifiant interne unique du lot dans le registre.';

--
-- Name: COLUMN "V_RegistreLots"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."ID_ArticleFk" IS 'Article auquel appartient exclusivement le lot.';

--
-- Name: COLUMN "V_RegistreLots"."NumeroLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."NumeroLot" IS 'Numéro de lot du produit, conservé en texte.';

--
-- Name: COLUMN "V_RegistreLots"."DatePeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."DatePeremptionLot" IS 'Date civile de péremption propre au lot ; une absence reste inconnue.';

--
-- Name: COLUMN "V_RegistreLots"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."Actif" IS 'Lot actif. Un lot archivé reste visible et ses mouvements sont conservés.';

--
-- Name: COLUMN "V_RegistreLots"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."CreeLe" IS 'Horodatage de création du lot.';

--
-- Name: COLUMN "V_RegistreLots"."StockLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."StockLot" IS 'Solde réel du lot : entrées moins sorties dans son unité de stock.';

--
-- Name: COLUMN "V_RegistreLots"."QuantiteEntree"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."QuantiteEntree" IS 'Quantité cumulée des entrées ventilées sur ce lot, dans son unité.';

--
-- Name: COLUMN "V_RegistreLots"."QuantiteSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."QuantiteSortie" IS 'Quantité cumulée des sorties ventilées sur ce lot, dans son unité.';

--
-- Name: COLUMN "V_RegistreLots"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."ID_DeviseFk" IS 'Devise de référence du mouvement ou de l’article ; aucun total entre devises.';

--
-- Name: COLUMN "V_RegistreLots"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."DeviseCode" IS 'Code de la devise de référence.';

--
-- Name: COLUMN "V_RegistreLots"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."DeviseLibelle" IS 'Libellé de la devise de référence.';

--
-- Name: COLUMN "V_RegistreLots"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."IdEntiteFk" IS 'Entreprise propriétaire durable de l’article ; clé du périmètre de consultation.';

--
-- Name: COLUMN "V_RegistreLots"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."NomArticle" IS 'Désignation actuelle de l’article du lot.';

--
-- Name: COLUMN "V_RegistreLots"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."ID_UniteFk" IS 'Unité de stock définie dans le référentiel générique.';

--
-- Name: COLUMN "V_RegistreLots"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."Unite" IS 'Abréviation de l’unité de stock associée aux quantités du lot ou de son mouvement.';

--
-- Name: COLUMN "V_RegistreLots"."EtatPeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."EtatPeremptionLot" IS 'Conservation du lot selon sa date et le seuil article ou entreprise ; indépendante du solde.';

--
-- Name: COLUMN "V_RegistreLots"."EstPerime"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."EstPerime" IS 'Date du lot antérieure au jour métier Africa/Kinshasa ; inclut les lots épuisés dans ce registre historique.';

--
-- Name: COLUMN "V_RegistreLots"."EstProche"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."EstProche" IS 'Date du lot entre le jour métier et le seuil d’alerte inclus.';

--
-- Name: COLUMN "V_RegistreLots"."SeuilAlerteJours"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."SeuilAlerteJours" IS 'Délai d’alerte effectif en jours : article, sinon entreprise, sinon 30.';

--
-- Name: COLUMN "V_RegistreLots"."BloquerLotsPerimes"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."BloquerLotsPerimes" IS 'Politique de blocage des sorties de lots périmés pour cette entreprise.';

--
-- Name: COLUMN "V_RegistreLots"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."CodeArticleInterne" IS 'Code interne actuel de l’article.';

--
-- Name: COLUMN "V_RegistreLots"."RefArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."RefArticle" IS 'Référence actuelle de l’article.';

--
-- Name: COLUMN "V_RegistreLots"."PhotoArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."PhotoArticle" IS 'Photo actuelle de l’article.';

--
-- Name: COLUMN "V_RegistreLots"."ID_CategorieArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."ID_CategorieArticleFk" IS 'Catégorie d’article dans le référentiel générique.';

--
-- Name: COLUMN "V_RegistreLots"."CategorieArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."CategorieArticle" IS 'Libellé de la catégorie d’article.';

--
-- Name: COLUMN "V_RegistreLots"."ID_TypeArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."ID_TypeArticleFk" IS 'Type d’article dans le référentiel générique.';

--
-- Name: COLUMN "V_RegistreLots"."TypeArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."TypeArticle" IS 'Libellé du type d’article.';

--
-- Name: COLUMN "V_RegistreLots"."ValideArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."ValideArticle" IS 'État actif de l’article. Ne modifie pas le solde historique du lot.';

--
-- Name: COLUMN "V_RegistreLots"."StockArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."StockArticle" IS 'Stock courant total de l’article, lots et stock sans lot compris ; non sommable entre unités.';

--
-- Name: COLUMN "V_RegistreLots"."AbrUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."AbrUnite" IS 'Abréviation de l’unité de stock, exportée avec toute quantité.';

--
-- Name: COLUMN "V_RegistreLots"."NomEntite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."NomEntite" IS 'Nom de l’entreprise propriétaire de l’article.';

--
-- Name: COLUMN "V_RegistreLots"."EtatStockLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreLots"."EtatStockLot" IS 'État du solde du lot : Disponible, Épuisé ou Stock négatif.';

--
-- Name: V_RegistreMouvementLot; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_RegistreMouvementLot" AS
 SELECT l."ID_MvtFk",
    l."ID_LotArticleFk",
    l."ID_ArticleFk",
    l."NumeroLot",
    l."DatePeremptionLot",
    l."Quantite",
    l."DateMvt",
    l."ID_cmdFk",
    l."SigneStock",
    l."QuantiteSignee",
    l."NomArticle",
    l."CodeCmd",
    l."ID_DeviseFk",
    l."DeviseCode",
    l."DeviseLibelle",
    l."MotifDerogationPeremption",
    l."ID_DerogationUserFk",
    l."DateDerogationPeremption",
    a."IdEntiteFk",
    a."CodeArticleInterne",
    a."RefArticle",
    u."AbrGenerique" AS "AbrUnite",
    u."AbrGenerique" AS "Unite",
    t."NomGenerique" AS "NomTypeMvt",
        CASE
            WHEN (l."SigneStock" = 1) THEN 'Entrée'::text
            WHEN (l."SigneStock" = '-1'::integer) THEN 'Sortie'::text
            ELSE 'Sans effet'::text
        END AS "SensMouvement"
   FROM ((((logistique."V_MouvementLot" l
     JOIN logistique."T_Article" a ON ((a."ID_Article" = l."ID_ArticleFk")))
     JOIN logistique."T_Mouvement" m ON ((m."ID_Mvt" = l."ID_MvtFk")))
     LEFT JOIN referentiel."T_Generique" u ON ((u."ID_Generique" = a."ID_UniteFk")))
     LEFT JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = m."ID_TypeMvtFk")));

--
-- Name: VIEW "V_RegistreMouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_RegistreMouvementLot" IS 'Journal des ventilations de mouvements par lot avec quantité, signe, unité et entreprise. Une ligne par mouvement et lot ; consulter et exporter en filtrant ID_LotArticleFk. Les mouvements d’origine et leurs compensations restent distincts.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."ID_MvtFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."ID_MvtFk" IS 'Identifiant du mouvement source de cette ventilation de lot.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."ID_LotArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."ID_LotArticleFk" IS 'Lot dont cette écriture ventile une partie du mouvement.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."ID_ArticleFk" IS 'Article auquel appartient exclusivement le lot.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."NumeroLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."NumeroLot" IS 'Numéro de lot du produit, conservé en texte.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."DatePeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."DatePeremptionLot" IS 'Date civile de péremption propre au lot ; une absence reste inconnue.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."Quantite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."Quantite" IS 'Quantité absolue de cette ventilation, dans l’unité de stock de l’article.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."DateMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."DateMvt" IS 'Date et heure métier du mouvement source.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."ID_cmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."ID_cmdFk" IS 'Bon de stock source, si présent.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."SigneStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."SigneStock" IS 'Effet de stock de la ventilation : 1 entrée, -1 sortie, 0 neutre.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."QuantiteSignee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."QuantiteSignee" IS 'Quantité de ventilation multipliée par son signe de stock.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."NomArticle" IS 'Désignation actuelle de l’article du lot.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."CodeCmd" IS 'Code automatique du bon source, si présent.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."ID_DeviseFk" IS 'Devise de référence du mouvement ou de l’article ; aucun total entre devises.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."DeviseCode" IS 'Code de la devise de référence.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."DeviseLibelle" IS 'Libellé de la devise de référence.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."MotifDerogationPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."MotifDerogationPeremption" IS 'Motif obligatoire d’une dérogation autorisée au blocage des lots périmés.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."ID_DerogationUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."ID_DerogationUserFk" IS 'Administrateur global ayant autorisé la dérogation de péremption.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."DateDerogationPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."DateDerogationPeremption" IS 'Horodatage de l’autorisation de dérogation.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."IdEntiteFk" IS 'Entreprise propriétaire durable de l’article ; clé du périmètre de consultation.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."CodeArticleInterne" IS 'Code interne actuel de l’article.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."RefArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."RefArticle" IS 'Référence actuelle de l’article.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."AbrUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."AbrUnite" IS 'Abréviation de l’unité de stock, exportée avec toute quantité.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."Unite" IS 'Abréviation de l’unité de stock associée aux quantités du lot ou de son mouvement.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."NomTypeMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."NomTypeMvt" IS 'Type du mouvement source issu du référentiel générique.';

--
-- Name: COLUMN "V_RegistreMouvementLot"."SensMouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RegistreMouvementLot"."SensMouvement" IS 'Sens lisible de l’écriture, dérivé du signe de stock.';

--
-- Name: V_Reglements; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_Reglements" AS
 SELECT source."ID_Reglement",
    source."CodeFactureFk",
    source."ID_ModeReglementFk",
    source."ID_ClientFk",
    source."DateReglement",
    source."MontantRegle",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk",
    r."ID_TiersFk",
    t."Nom" AS "TiersNom"
   FROM ((( SELECT r_1."ID_Reglement",
            r_1."CodeFactureFk",
            r_1."ID_ModeReglementFk",
            r_1."ID_ClientFk",
            r_1."DateReglement",
            r_1."MontantRegle",
            r_1."ID_DeviseFk",
            logistique.fn_code_devise((g."AbrGenerique")::text) AS "DeviseCode",
            (g."NomGenerique")::text AS "DeviseLibelle"
           FROM (logistique."T_Reglements" r_1
             LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = r_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Commande" r ON (((r."CodeFacture")::text = (source."CodeFactureFk")::text)))
     LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")));

--
-- Name: VIEW "V_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_Reglements" IS 'Écritures unitaires de règlement avec devise historique de la facture ; le service impose utilisateur, organisation et facture autorisés.';

--
-- Name: COLUMN "V_Reglements"."ID_Reglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."ID_Reglement" IS 'Identifiant unique du règlement.';

--
-- Name: COLUMN "V_Reglements"."CodeFactureFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."CodeFactureFk" IS 'Référence unique de la facture du bon source.';

--
-- Name: COLUMN "V_Reglements"."ID_ModeReglementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."ID_ModeReglementFk" IS 'Mode de paiement validé par la logique métier existante.';

--
-- Name: COLUMN "V_Reglements"."ID_ClientFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."ID_ClientFk" IS 'Client rattaché au règlement.';

--
-- Name: COLUMN "V_Reglements"."DateReglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."DateReglement" IS 'Horodatage métier du règlement, sans fuseau dans le modèle existant.';

--
-- Name: COLUMN "V_Reglements"."MontantRegle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."MontantRegle" IS 'Montant exact dans la devise de la facture ; aucune conversion.';

--
-- Name: COLUMN "V_Reglements"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."ID_DeviseFk" IS 'Référence de devise du règlement historique ; aucune conversion.';

--
-- Name: COLUMN "V_Reglements"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';

--
-- Name: COLUMN "V_Reglements"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

--
-- Name: COLUMN "V_Reglements"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Reglements"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."ID_TiersFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_Reglements"."TiersNom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_Reglements"."TiersNom" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: V_RetourArticle; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_RetourArticle" AS
 WITH mouvements AS (
         SELECT "T_Mouvement"."ID_cmdFk",
            "T_Mouvement"."ID_ArticleFk",
            count(*) AS n,
            max("T_Mouvement"."ID_Mvt") AS mvt,
            max("T_Mouvement"."QteMvt") AS qte,
            max("T_Mouvement"."PUMvt") AS pu,
            max("T_Mouvement"."ID_DeviseFk") AS devise,
            max("T_Mouvement"."ID_TypeMvtFk") AS type_id
           FROM logistique."T_Mouvement"
          WHERE ("T_Mouvement"."ID_cmdFk" IS NOT NULL)
          GROUP BY "T_Mouvement"."ID_cmdFk", "T_Mouvement"."ID_ArticleFk"
        ), lots AS (
         SELECT m_1."ID_cmdFk",
            m_1."ID_ArticleFk",
            sum(l_1."Quantite") AS qte
           FROM (logistique."T_Mouvement" m_1
             JOIN logistique."T_MouvementLot" l_1 ON ((l_1."ID_MvtFk" = m_1."ID_Mvt")))
          GROUP BY m_1."ID_cmdFk", m_1."ID_ArticleFk"
        ), rendus AS (
         SELECT r_1."ID_CommandeOrigineFk" AS origine,
            d_1."ID_ArticleFk",
            sum(d_1."QteCmdDetail") AS qte,
            sum((d_1."QteCmdDetail" - COALESCE(l_1.qte, ((0)::bigint)::numeric))) AS sans_lot
           FROM ((logistique."T_RetourBon" r_1
             JOIN logistique."T_CommandeDetail" d_1 ON ((d_1."ID_CmdFk" = r_1."ID_CommandeRetourFk")))
             LEFT JOIN lots l_1 ON (((l_1."ID_cmdFk" = d_1."ID_CmdFk") AND (l_1."ID_ArticleFk" = d_1."ID_ArticleFk"))))
          GROUP BY r_1."ID_CommandeOrigineFk", d_1."ID_ArticleFk"
        )
 SELECT c."ID_Commande" AS "ID_CommandeOrigineFk",
    d."ID_ArticleFk",
    m.mvt AS "ID_MouvementOrigineFk",
    a."NomArticle",
    a."CodeArticleInterne",
    u."AbrGenerique" AS "AbrUnite",
    c."ID_DeviseFk",
    cv."DeviseCode",
    cv."DeviseLibelle",
    m.pu AS "PUHistorique",
    d."QteCmdDetail" AS "QteSortie",
    COALESCE(r.qte, (0)::numeric) AS "QteDejaRetournee",
    (d."QteCmdDetail" - COALESCE(r.qte, (0)::numeric)) AS "QteRestante",
    (d."QteCmdDetail" - COALESCE(l.qte, ((0)::bigint)::numeric)) AS "QteSansLotSortie",
    COALESCE(r.sans_lot, (0)::numeric) AS "QteSansLotDejaRetournee",
    ((d."QteCmdDetail" - COALESCE(l.qte, ((0)::bigint)::numeric)) - COALESCE(r.sans_lot, (0)::numeric)) AS "QteSansLotRestante",
    (((m.n = 1) AND (m.qte = d."QteCmdDetail") AND (m.pu IS NOT NULL) AND (m.pu >= (0)::numeric) AND (m.pu <= 9999999999.99) AND (m.devise = c."ID_DeviseFk") AND (c."ID_DeviseFk" IS NOT NULL) AND (m.type_id = c."ID_TypeCmdFk") AND (d."QteCmdDetail" > (0)::numeric) AND (COALESCE(l.qte, ((0)::bigint)::numeric) <= d."QteCmdDetail")) IS TRUE) AS "SourceCoherente"
   FROM ((((((((logistique."T_Commande" c
     JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = c."ID_TypeCmdFk")))
     JOIN logistique."T_CommandeDetail" d ON ((d."ID_CmdFk" = c."ID_Commande")))
     JOIN logistique."T_Article" a ON ((a."ID_Article" = d."ID_ArticleFk")))
     LEFT JOIN referentiel."T_Generique" u ON ((u."ID_Generique" = a."ID_UniteFk")))
     LEFT JOIN logistique."V_Commande" cv ON ((cv."ID_Commande" = c."ID_Commande")))
     LEFT JOIN mouvements m ON (((m."ID_cmdFk" = d."ID_CmdFk") AND (m."ID_ArticleFk" = d."ID_ArticleFk"))))
     LEFT JOIN lots l ON (((l."ID_cmdFk" = d."ID_CmdFk") AND (l."ID_ArticleFk" = d."ID_ArticleFk"))))
     LEFT JOIN rendus r ON (((r.origine = d."ID_CmdFk") AND (r."ID_ArticleFk" = d."ID_ArticleFk"))))
  WHERE (logistique.fn_nature_bon(c."ID_TypeCmdFk") = 'sortie'::text);

--
-- Name: VIEW "V_RetourArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_RetourArticle" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

--
-- Name: COLUMN "V_RetourArticle"."ID_CommandeOrigineFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."ID_CommandeOrigineFk" IS 'Bon de sortie historique.';

--
-- Name: COLUMN "V_RetourArticle"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."ID_ArticleFk" IS 'Article de la ligne d’origine.';

--
-- Name: COLUMN "V_RetourArticle"."ID_MouvementOrigineFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."ID_MouvementOrigineFk" IS 'Mouvement sortant historique unique.';

--
-- Name: COLUMN "V_RetourArticle"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."NomArticle" IS 'Libellé actuel de l’article sans effet sur sa quantité historique.';

--
-- Name: COLUMN "V_RetourArticle"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."CodeArticleInterne" IS 'Code interne de l’article.';

--
-- Name: COLUMN "V_RetourArticle"."AbrUnite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."AbrUnite" IS 'Unité de stock.';

--
-- Name: COLUMN "V_RetourArticle"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."ID_DeviseFk" IS 'Devise conservée du bon d’origine.';

--
-- Name: COLUMN "V_RetourArticle"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."DeviseCode" IS 'Code normalisé de devise, sans conversion.';

--
-- Name: COLUMN "V_RetourArticle"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."DeviseLibelle" IS 'Libellé de la devise.';

--
-- Name: COLUMN "V_RetourArticle"."PUHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."PUHistorique" IS 'Prix unitaire réellement porté par le mouvement sortant, indépendant du catalogue actuel.';

--
-- Name: COLUMN "V_RetourArticle"."QteSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."QteSortie" IS 'Quantité entière initialement sortie.';

--
-- Name: COLUMN "V_RetourArticle"."QteDejaRetournee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."QteDejaRetournee" IS 'Cumul des événements de retour validés pour cet article.';

--
-- Name: COLUMN "V_RetourArticle"."QteRestante"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."QteRestante" IS 'Quantité sortie encore restituable.';

--
-- Name: COLUMN "V_RetourArticle"."QteSansLotSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."QteSansLotSortie" IS 'Part de la sortie qui ne portait pas de ventilation de lot.';

--
-- Name: COLUMN "V_RetourArticle"."QteSansLotDejaRetournee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."QteSansLotDejaRetournee" IS 'Part déjà restituée sans affectation à un lot.';

--
-- Name: COLUMN "V_RetourArticle"."QteSansLotRestante"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."QteSansLotRestante" IS 'Part sans lot encore restituable.';

--
-- Name: COLUMN "V_RetourArticle"."SourceCoherente"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourArticle"."SourceCoherente" IS 'Vrai si ligne et mouvement source sont cohérents en quantité, prix, sens et devise.';

--
-- Name: V_RetourBon; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_RetourBon" AS
 SELECT r."ID_RetourBon",
    r."ID_CommandeOrigineFk",
    r."ID_CommandeRetourFk",
    r."ID_UserFk",
    r."IdEntiteFk",
    r."RequestId",
    r."PayloadHash",
    r."Motif",
    r."DateRetour",
    r."CreeLe",
    o."CodeCmd" AS "CodeBonOrigine",
    b."CodeCmd",
    b."DateCmd",
    b."NbLignes",
    b."MontantTTC",
    b."ID_DeviseFk",
    b."DeviseCode",
    b."DeviseLibelle",
    TRIM(BOTH FROM concat_ws(' '::text, u."PrenomUser", u."NomUser")) AS "NomComplet"
   FROM (((logistique."T_RetourBon" r
     JOIN logistique."V_Commande" o ON ((o."ID_Commande" = r."ID_CommandeOrigineFk")))
     JOIN logistique."V_Commande" b ON ((b."ID_Commande" = r."ID_CommandeRetourFk")))
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = r."ID_UserFk")));

--
-- Name: VIEW "V_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_RetourBon" IS 'Documents compensateurs de retours physiques avec origine, motif, auteur, devise et horodatage ; ne représente ni un avoir ni un remboursement.';

--
-- Name: COLUMN "V_RetourBon"."ID_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."ID_RetourBon" IS 'Identifiant de l’événement de retour.';

--
-- Name: COLUMN "V_RetourBon"."ID_CommandeOrigineFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."ID_CommandeOrigineFk" IS 'Sortie compensée.';

--
-- Name: COLUMN "V_RetourBon"."ID_CommandeRetourFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."ID_CommandeRetourFk" IS 'Entrée compensatrice.';

--
-- Name: COLUMN "V_RetourBon"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."ID_UserFk" IS 'Auteur du retour.';

--
-- Name: COLUMN "V_RetourBon"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_RetourBon"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."RequestId" IS 'Demande idempotente unique pour son auteur.';

--
-- Name: COLUMN "V_RetourBon"."PayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."PayloadHash" IS 'Empreinte exacte de la demande validée.';

--
-- Name: COLUMN "V_RetourBon"."Motif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."Motif" IS 'Motif humain de restitution.';

--
-- Name: COLUMN "V_RetourBon"."DateRetour"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."DateRetour" IS 'Date et heure métier du retour.';

--
-- Name: COLUMN "V_RetourBon"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."CreeLe" IS 'Horodatage d’enregistrement.';

--
-- Name: COLUMN "V_RetourBon"."CodeBonOrigine"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."CodeBonOrigine" IS 'Référence automatique de la sortie.';

--
-- Name: COLUMN "V_RetourBon"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."CodeCmd" IS 'Référence automatique du bon d’entrée compensateur.';

--
-- Name: COLUMN "V_RetourBon"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."DateCmd" IS 'Date métier du document compensateur.';

--
-- Name: COLUMN "V_RetourBon"."NbLignes"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."NbLignes" IS 'Nombre d’articles distincts restitués dans cet événement.';

--
-- Name: COLUMN "V_RetourBon"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."MontantTTC" IS 'Valeur du retour au prix historique de sortie ; ce montant n’est pas un remboursement.';

--
-- Name: COLUMN "V_RetourBon"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."ID_DeviseFk" IS 'Devise de la sortie et de la contre-écriture.';

--
-- Name: COLUMN "V_RetourBon"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."DeviseCode" IS 'Code normalisé de cette devise.';

--
-- Name: COLUMN "V_RetourBon"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."DeviseLibelle" IS 'Libellé de cette devise.';

--
-- Name: COLUMN "V_RetourBon"."NomComplet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourBon"."NomComplet" IS 'Nom affiché de l’auteur.';

--
-- Name: V_RetourLot; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_RetourLot" AS
 WITH rendus AS (
         SELECT r_1."ID_CommandeOrigineFk" AS origine,
            m_1."ID_ArticleFk",
            ml_1."ID_LotArticleFk",
            sum(ml_1."Quantite") AS qte
           FROM ((logistique."T_RetourBon" r_1
             JOIN logistique."T_Mouvement" m_1 ON ((m_1."ID_cmdFk" = r_1."ID_CommandeRetourFk")))
             JOIN logistique."T_MouvementLot" ml_1 ON ((ml_1."ID_MvtFk" = m_1."ID_Mvt")))
          GROUP BY r_1."ID_CommandeOrigineFk", m_1."ID_ArticleFk", ml_1."ID_LotArticleFk"
        )
 SELECT m."ID_cmdFk" AS "ID_CommandeOrigineFk",
    m."ID_ArticleFk",
    l."ID_LotArticle",
    l."NumeroLot",
    l."DatePeremptionLot",
    sum(ml."Quantite") AS "QteSortie",
    COALESCE(max(r.qte), ((0)::bigint)::numeric) AS "QteDejaRetournee",
    (sum(ml."Quantite") - COALESCE(max(r.qte), ((0)::bigint)::numeric)) AS "QteRestante"
   FROM (((((logistique."T_Mouvement" m
     JOIN logistique."T_Commande" c ON ((c."ID_Commande" = m."ID_cmdFk")))
     JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = c."ID_TypeCmdFk")))
     JOIN logistique."T_MouvementLot" ml ON ((ml."ID_MvtFk" = m."ID_Mvt")))
     JOIN logistique."T_LotArticle" l ON ((l."ID_LotArticle" = ml."ID_LotArticleFk")))
     LEFT JOIN rendus r ON (((r.origine = m."ID_cmdFk") AND (r."ID_ArticleFk" = m."ID_ArticleFk") AND (r."ID_LotArticleFk" = l."ID_LotArticle"))))
  WHERE (logistique.fn_nature_bon(c."ID_TypeCmdFk") = 'sortie'::text)
  GROUP BY m."ID_cmdFk", m."ID_ArticleFk", l."ID_LotArticle", l."NumeroLot", l."DatePeremptionLot";

--
-- Name: VIEW "V_RetourLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_RetourLot" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

--
-- Name: COLUMN "V_RetourLot"."ID_CommandeOrigineFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourLot"."ID_CommandeOrigineFk" IS 'Bon de sortie historique.';

--
-- Name: COLUMN "V_RetourLot"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourLot"."ID_ArticleFk" IS 'Article sorti.';

--
-- Name: COLUMN "V_RetourLot"."ID_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourLot"."ID_LotArticle" IS 'Identifiant du lot réellement sorti.';

--
-- Name: COLUMN "V_RetourLot"."NumeroLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourLot"."NumeroLot" IS 'Numéro conservé du lot source.';

--
-- Name: COLUMN "V_RetourLot"."DatePeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourLot"."DatePeremptionLot" IS 'Péremption historique du lot.';

--
-- Name: COLUMN "V_RetourLot"."QteSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourLot"."QteSortie" IS 'Quantité de ce lot sortie sur le bon.';

--
-- Name: COLUMN "V_RetourLot"."QteDejaRetournee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourLot"."QteDejaRetournee" IS 'Quantité cumulée rendue de ce lot sur les retours de cette origine.';

--
-- Name: COLUMN "V_RetourLot"."QteRestante"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_RetourLot"."QteRestante" IS 'Quantité de ce lot encore restituable.';

--
-- Name: V_SuiviReglements; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_SuiviReglements" AS
 SELECT v."ID_Commande",
    v."CodeCmd",
    v."CodeFacture",
    v."DateFacture",
    v."DateEcheancePaiement",
    v."NomClientSaisi",
    v."MontantTTC",
    v."TotalRegle",
    v."Reste",
    v."NbReglements",
    v."DernierReglement",
    v."EtatReglement",
    v."EstEnRetard",
    v."JoursAvantEcheance",
    v."ID_DeviseFk",
    v."DeviseCode",
    v."DeviseLibelle",
    v."ID_Facture",
    v."EstFactureSnapshot",
    v."MontantFacture",
    v."MontantAvoirAEtablir",
    v."AvoirAEtablir",
    v."MontantBon",
    v."IdEntiteFk",
    v."ID_TiersFk",
    v."TiersNom",
    v."ID_DestinationFk",
    v."DestinationLibelle",
    v."AvoirImpute",
    v."MontantNetARegler",
    f."TauxTVA",
    f."MontantTVA",
    f."MontantHT" AS "MontantHTFacture"
   FROM (( SELECT b."ID_Commande",
            b."CodeCmd",
            b."CodeFacture",
            b."DateFacture",
            b."DateEcheancePaiement",
            b."NomClientSaisi",
            b."MontantTTC",
            b."TotalRegle",
            b."Reste",
            b."NbReglements",
            b."DernierReglement",
            b."EtatReglement",
            b."EstEnRetard",
            b."JoursAvantEcheance",
            b."ID_DeviseFk",
            b."DeviseCode",
            b."DeviseLibelle",
            b."ID_Facture",
            b."EstFactureSnapshot",
            b."MontantFacture",
            (logistique.fn_montant_avoir_attente(b."ID_Commande"))::numeric(12,2) AS "MontantAvoirAEtablir",
            (logistique.fn_montant_avoir_attente(b."ID_Commande") > (0)::numeric) AS "AvoirAEtablir",
            b."MontantBon",
            b."IdEntiteFk",
            b."ID_TiersFk",
            b."TiersNom",
            b."ID_DestinationFk",
            b."DestinationLibelle",
            (COALESCE(cr.total, (0)::numeric))::numeric(12,2) AS "AvoirImpute",
            ((b."MontantFacture" - COALESCE(cr.total, (0)::numeric)))::numeric(12,2) AS "MontantNetARegler"
           FROM (( SELECT s."ID_Commande",
                    s."CodeCmd",
                    s."CodeFacture",
                    s."DateFacture",
                    s."DateEcheancePaiement",
                    s."NomClientSaisi",
                    s."MontantTTC",
                    s."TotalRegle",
                    s."Reste",
                    s."NbReglements",
                    s."DernierReglement",
                    s."EtatReglement",
                    s."EstEnRetard",
                    s."JoursAvantEcheance",
                    s."ID_DeviseFk",
                    s."DeviseCode",
                    s."DeviseLibelle",
                    s."ID_Facture",
                    s."EstFactureSnapshot",
                    s."MontantFacture",
                    s."MontantAvoirAEtablir",
                    s."AvoirAEtablir",
                    s."MontantBon",
                    s."IdEntiteFk",
                    s."ID_TiersFk",
                    s."TiersNom",
                    c."ID_DestinationFk",
                    d.label AS "DestinationLibelle"
                   FROM ((( SELECT source."ID_Commande",
                            source."CodeCmd",
                            source."CodeFacture",
                            source."DateFacture",
                            source."DateEcheancePaiement",
                            source."NomClientSaisi",
                            source."MontantTTC",
                            source."TotalRegle",
                            source."Reste",
                            source."NbReglements",
                            source."DernierReglement",
                            source."EtatReglement",
                            source."EstEnRetard",
                            source."JoursAvantEcheance",
                            source."ID_DeviseFk",
                            source."DeviseCode",
                            source."DeviseLibelle",
                            source."ID_Facture",
                            source."EstFactureSnapshot",
                            source."MontantFacture",
                            source."MontantAvoirAEtablir",
                            source."AvoirAEtablir",
                            source."MontantBon",
                            r."IdEntiteFk",
                            r."ID_TiersFk",
                            t."Nom" AS "TiersNom"
                           FROM ((( SELECT base."ID_Commande",
                                    base."CodeCmd",
                                    base."CodeFacture",
                                    base."DateFacture",
                                    base."DateEcheancePaiement",
                                    base."NomClientSaisi",
                                    COALESCE(f_1."MontantTTC", base."MontantTTC") AS "MontantTTC",
                                    COALESCE(f_1."TotalRegle", base."TotalRegle") AS "TotalRegle",
                                    COALESCE(f_1."Reste", base."Reste") AS "Reste",
                                    base."NbReglements",
                                    base."DernierReglement",
                                    COALESCE(f_1."EtatReglement", base."EtatReglement") AS "EtatReglement",
                                    COALESCE(f_1."EstEnRetard", base."EstEnRetard") AS "EstEnRetard",
                                    base."JoursAvantEcheance",
                                    base."ID_DeviseFk",
                                    COALESCE(f_1."DeviseCode", base."DeviseCode") AS "DeviseCode",
                                    COALESCE(f_1."DeviseLibelle", base."DeviseLibelle") AS "DeviseLibelle",
                                    f_1."ID_Facture",
                                    (f_1."ID_Facture" IS NOT NULL) AS "EstFactureSnapshot",
                                    (
CASE
 WHEN (NULLIF(btrim((base."CodeFacture")::text), ''::text) IS NOT NULL) THEN COALESCE(f_1."MontantTTC", base."MontantTTC")
 ELSE NULL::numeric
END)::numeric(12,2) AS "MontantFacture",
                                    (COALESCE(f_1."MontantAvoirAEtablir", (0)::numeric))::numeric(12,2) AS "MontantAvoirAEtablir",
                                    COALESCE(f_1."AvoirAEtablir", false) AS "AvoirAEtablir",
                                    base."MontantTTC" AS "MontantBon"
                                   FROM (( SELECT historique."ID_Commande",
    historique."CodeCmd",
    historique."CodeFacture",
    historique."DateFacture",
    historique."DateEcheancePaiement",
    historique."NomClientSaisi",
    historique."MontantTTC",
    historique."TotalRegle",
    historique."Reste",
    historique."NbReglements",
    historique."DernierReglement",
    historique."EtatReglement",
    historique."EstEnRetard",
    historique."JoursAvantEcheance",
    source_1."ID_DeviseFk",
    logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
    (devise."NomGenerique")::text AS "DeviseLibelle"
   FROM ((( SELECT c_1."ID_Commande",
      c_1."CodeCmd",
      c_1."CodeFacture",
      c_1."DateFacture",
      c_1."DateEcheancePaiement",
      c_1."NomClientSaisi",
      (COALESCE(c_1."MontantTTC", (0)::numeric))::numeric(12,2) AS "MontantTTC",
      (COALESCE(sum(r_1."MontantRegle"), (0)::numeric))::numeric(12,2) AS "TotalRegle",
      ((COALESCE(c_1."MontantTTC", (0)::numeric) - COALESCE(sum(r_1."MontantRegle"), (0)::numeric)))::numeric(12,2) AS "Reste",
      count(r_1."ID_Reglement") AS "NbReglements",
      max(r_1."DateReglement") AS "DernierReglement",
    CASE
     WHEN (c_1."CodeFacture" IS NULL) THEN 'Non facturée'::text
     WHEN (COALESCE(c_1."MontantTTC", (0)::numeric) = (0)::numeric) THEN 'Montant nul'::text
     WHEN (COALESCE(sum(r_1."MontantRegle"), (0)::numeric) <= (0)::numeric) THEN 'Non réglée'::text
     WHEN (COALESCE(sum(r_1."MontantRegle"), (0)::numeric) < COALESCE(c_1."MontantTTC", (0)::numeric)) THEN 'Partiellement réglée'::text
     ELSE 'Réglée'::text
    END AS "EtatReglement",
      ((c_1."DateEcheancePaiement" IS NOT NULL) AND ((c_1."DateEcheancePaiement")::date < CURRENT_DATE) AND ((COALESCE(c_1."MontantTTC", (0)::numeric) - COALESCE(sum(r_1."MontantRegle"), (0)::numeric)) > (0)::numeric)) AS "EstEnRetard",
    CASE
     WHEN (c_1."DateEcheancePaiement" IS NOT NULL) THEN ((c_1."DateEcheancePaiement")::date - CURRENT_DATE)
     ELSE NULL::integer
    END AS "JoursAvantEcheance"
     FROM (logistique."T_Commande" c_1
       LEFT JOIN logistique."T_Reglements" r_1 ON (((r_1."CodeFactureFk")::text = (c_1."CodeFacture")::text)))
    GROUP BY c_1."ID_Commande", c_1."CodeCmd", c_1."CodeFacture", c_1."DateFacture", c_1."DateEcheancePaiement", c_1."NomClientSaisi", c_1."MontantTTC") historique
     LEFT JOIN logistique."T_Commande" source_1 ON ((source_1."ID_Commande" = historique."ID_Commande")))
     LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) base
                                     LEFT JOIN logistique."V_Facture" f_1 ON ((f_1."ID_CommandeFk" = base."ID_Commande")))) source
                             LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source."ID_Commande")))
                             LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")))) s
                     JOIN logistique."T_Commande" c ON ((c."ID_Commande" = s."ID_Commande")))
                     LEFT JOIN geolocalisation."V_DestinationLogistique" d ON ((d.id = c."ID_DestinationFk")))) b
             LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS total
                   FROM logistique."T_AvoirAffectation"
                  WHERE ("T_AvoirAffectation"."ID_CommandeCibleFk" = b."ID_Commande")) cr ON (true))) v
     LEFT JOIN logistique."T_Facture" f ON ((f."ID_CommandeFk" = v."ID_Commande")));

--
-- Name: VIEW "V_SuiviReglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_SuiviReglements" IS 'Registre documentaire et suivi des montants, avec fiscalité de la facture émise jointe sans modifier le stock ni les totaux physiques du bon.';

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

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantTTC" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_SuiviReglements"."TotalRegle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."TotalRegle" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_SuiviReglements"."Reste"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."Reste" IS 'Montant de la facture diminué des règlements et des avoirs imputés.';

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

COMMENT ON COLUMN logistique."V_SuiviReglements"."EtatReglement" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_SuiviReglements"."EstEnRetard"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."EstEnRetard" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_SuiviReglements"."JoursAvantEcheance"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."JoursAvantEcheance" IS 'Échéance de paiement moins CURRENT_DATE, en jours ; négatif après échéance et NULL sans date. Expression projetée : CASE WHEN c."DateEcheancePaiement" IS NOT NULL THEN c."DateEcheancePaiement"::date - CURRENT_DATE ELSE NULL::integer END AS "JoursAvantEcheance".';

--
-- Name: COLUMN "V_SuiviReglements"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';

--
-- Name: COLUMN "V_SuiviReglements"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."DeviseCode" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_SuiviReglements"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."DeviseLibelle" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';

--
-- Name: COLUMN "V_SuiviReglements"."ID_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."ID_Facture" IS 'Identité interne de la facture, indépendante du code lisible.';

--
-- Name: COLUMN "V_SuiviReglements"."EstFactureSnapshot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."EstFactureSnapshot" IS 'Vrai lorsqu’un instantané financier versionné existe.';

--
-- Name: COLUMN "V_SuiviReglements"."MontantFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantFacture" IS 'Montant du snapshot émis, NULL pour un bon non facturé ; historique conservé en compatibilité.';

--
-- Name: COLUMN "V_SuiviReglements"."MontantAvoirAEtablir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantAvoirAEtablir" IS 'Contrevaleur des retours postérieurs à l’émission ; aucun remboursement créé.';

--
-- Name: COLUMN "V_SuiviReglements"."AvoirAEtablir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."AvoirAEtablir" IS 'Des retours postérieurs nécessitent un avoir distinct ; la facture émise reste inchangée.';

--
-- Name: COLUMN "V_SuiviReglements"."MontantBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantBon" IS 'Montant initial du bon de stock, indépendant du net facturé.';

--
-- Name: COLUMN "V_SuiviReglements"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."IdEntiteFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_SuiviReglements"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."ID_TiersFk" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_SuiviReglements"."TiersNom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."TiersNom" IS 'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.';

--
-- Name: COLUMN "V_SuiviReglements"."ID_DestinationFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."ID_DestinationFk" IS 'Lieu référencé ou chemin géographique existant : ID_DestinationFk. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_SuiviReglements"."DestinationLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."DestinationLibelle" IS 'Lieu référencé ou chemin géographique existant : DestinationLibelle. Aucun identifiant n’est déduit du texte libre.';

--
-- Name: COLUMN "V_SuiviReglements"."AvoirImpute"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."AvoirImpute" IS 'Total des avoirs imputés à la facture, dans sa devise.';

--
-- Name: COLUMN "V_SuiviReglements"."MontantNetARegler"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantNetARegler" IS 'Montant facturé diminué des imputations d’avoirs, avant déduction des règlements.';

--
-- Name: COLUMN "V_SuiviReglements"."TauxTVA"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."TauxTVA" IS 'Taux historique de la facture émise, distinct du taux courant de l’entreprise.';

--
-- Name: COLUMN "V_SuiviReglements"."MontantTVA"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantTVA" IS 'TVA de la facture émise, sans modification des totaux physiques du bon.';

--
-- Name: COLUMN "V_SuiviReglements"."MontantHTFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantHTFacture" IS 'Montant HT immuable de la facture émise ; les retours postérieurs produisent un avoir séparé.';

--
-- Name: V_ValorisationStock; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_ValorisationStock" AS
 WITH keys AS (
         SELECT "T_ValorisationOuverture"."ID_ArticleFk",
            "T_ValorisationOuverture"."ID_DeviseFk"
           FROM logistique."T_ValorisationOuverture"
        UNION
         SELECT "T_Mouvement"."ID_ArticleFk",
            "T_Mouvement"."ID_DeviseFk"
           FROM logistique."T_Mouvement"
          WHERE ("T_Mouvement"."ID_DeviseFk" IS NOT NULL)
        )
 SELECT a."ID_Article",
    a."IdEntiteFk",
    k."ID_DeviseFk",
    g."AbrGenerique" AS "DeviseCode",
    a."NomArticle",
    COALESCE(l."StockApres", o."QuantiteOuverture", (0)::numeric) AS "QteValorisee",
        CASE
            WHEN (l."ID_Mvt" IS NOT NULL) THEN
            CASE
                WHEN (l."ValeurApres" IS NULL) THEN NULL::numeric
                WHEN (l."StockApres" > (0)::numeric) THEN round((l."ValeurApres" / l."StockApres"), 6)
                ELSE (0)::numeric
            END
            ELSE o."CoutOuverture"
        END AS "CoutUnitaireMoyen",
        CASE
            WHEN (l."ID_Mvt" IS NOT NULL) THEN round(l."ValeurApres", 2)
            ELSE round((o."QuantiteOuverture" * o."CoutOuverture"), 2)
        END AS "ValeurStock",
        CASE
            WHEN ((o."ID_ArticleFk" IS NOT NULL) AND (o."CoutOuverture" IS NULL)) THEN 'À initialiser'::text
            ELSE COALESCE(l."EtatValorisation", 'Calculé'::text)
        END AS "EtatValorisation",
    o."CoutOuverture",
    o."QuantiteOuverture",
    o."ID_MvtArrete",
    COALESCE(o."Version", (0)::bigint) AS "Version"
   FROM ((((keys k
     JOIN logistique."T_Article" a ON ((a."ID_Article" = k."ID_ArticleFk")))
     JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = k."ID_DeviseFk")))
     LEFT JOIN logistique."T_ValorisationOuverture" o ON (((o."ID_ArticleFk" = k."ID_ArticleFk") AND (o."ID_DeviseFk" = k."ID_DeviseFk"))))
     LEFT JOIN LATERAL ( SELECT f."ID_Mvt",
            f."ID_ArticleFk",
            f."ID_DeviseFk",
            f."IdEntiteFk",
            f."QteSignee",
            f."CoutUnitaire",
            f."ValeurMouvement",
            f."StockApres",
            f."ValeurApres",
            f."OrigineCout",
            f."EtatValorisation"
           FROM logistique.fn_cout_mouvements(k."ID_ArticleFk", k."ID_DeviseFk") f("ID_Mvt", "ID_ArticleFk", "ID_DeviseFk", "IdEntiteFk", "QteSignee", "CoutUnitaire", "ValeurMouvement", "StockApres", "ValeurApres", "OrigineCout", "EtatValorisation")
          WHERE (f."StockApres" IS NOT NULL)
          ORDER BY f."ID_Mvt" DESC
         LIMIT 1) l ON (true));

--
-- Name: VIEW "V_ValorisationStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_ValorisationStock" IS 'Stock valorisé CUMP par article, entreprise et devise. Aucune somme multidevise ni substitution du prix catalogue. À initialiser indique un coût d’ouverture historique non confirmé.';

--
-- Name: COLUMN "V_ValorisationStock"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."ID_Article" IS 'ID_Article : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."IdEntiteFk" IS 'IdEntiteFk : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."ID_DeviseFk" IS 'ID_DeviseFk : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."DeviseCode" IS 'DeviseCode : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."NomArticle" IS 'NomArticle : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."QteValorisee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."QteValorisee" IS 'QteValorisee : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."CoutUnitaireMoyen"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."CoutUnitaireMoyen" IS 'CoutUnitaireMoyen : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."ValeurStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."ValeurStock" IS 'ValeurStock : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."EtatValorisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."EtatValorisation" IS 'EtatValorisation : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."CoutOuverture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."CoutOuverture" IS 'CoutOuverture : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."QuantiteOuverture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."QuantiteOuverture" IS 'QuantiteOuverture : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."ID_MvtArrete"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."ID_MvtArrete" IS 'ID_MvtArrete : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';

--
-- Name: COLUMN "V_ValorisationStock"."Version"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_ValorisationStock"."Version" IS 'Version : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.';
--
-- Name: COLUMN "V_OffreArticle"."ID_CategorieArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."ID_CategorieArticleFk" IS 'Valeur centrale de catégorie déjà enregistrée sur l’article, destinée au filtre exact de l’annuaire ; aucune famille codée en dur.';

--
-- Name: COLUMN "V_OffreArticle"."CategorieArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."CategorieArticle" IS 'Abréviation courante de la catégorie centrale enregistrée, ou son nom si l’abréviation est absente. Ne normalise pas les produits entre entreprises.';

--
-- Name: COLUMN "V_OffreArticle"."ID_TypeArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."ID_TypeArticleFk" IS 'Valeur centrale de type déjà enregistrée sur l’article, destinée au filtre exact de l’annuaire ; aucune famille codée en dur.';

--
-- Name: COLUMN "V_OffreArticle"."TypeArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticle"."TypeArticle" IS 'Abréviation courante du type central enregistré, ou son nom si l’abréviation est absente. Ne constitue pas une qualification thérapeutique vérifiée.';

--
-- Name: V_OffreArticleLocalisation; Type: VIEW; Schema: logistique; Owner: -
--

CREATE VIEW logistique."V_OffreArticleLocalisation" AS
 SELECT o."ID_Article",
    COALESCE(NULLIF((l."NomNiveau_5")::text, ''::text), NULLIF((l."NomNiveau_4")::text, ''::text), NULLIF((l."NomNiveau_3")::text, ''::text), NULLIF(l."AdresseDetaillee", ''::text)) AS label,
    NULLIF(l."AdresseDetaillee", ''::text) AS address,
    NULLIF((l."NomNiveau_3")::text, ''::text) AS zone,
    NULLIF((l."NomNiveau_4")::text, ''::text) AS area,
    NULLIF((l."NomNiveau_5")::text, ''::text) AS site
   FROM (logistique."V_OffreArticle" o
     JOIN systeme."V_Entite_Localisation_Detail" l ON ((l."IdEntite" = o."IdEntite")))
  WHERE ((l."IdEntiteLocalisation" IS NOT NULL) AND (COALESCE(NULLIF((l."NomNiveau_5")::text, ''::text), NULLIF((l."NomNiveau_4")::text, ''::text), NULLIF((l."NomNiveau_3")::text, ''::text), NULLIF(l."AdresseDetaillee", ''::text)) IS NOT NULL));

--
-- Name: VIEW "V_OffreArticleLocalisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON VIEW logistique."V_OffreArticleLocalisation" IS 'Localisations professionnelles déclarées de l’entreprise d’une offre actuellement publiée. Grain article/localisation existante ; une offre sans localisation ne produit aucune ligne. Liste fermée de libellés et adresse, sans latitude, longitude, identifiant de point, auteur ou historique. Aucune distance, présence physique du stock sur ce site ou correspondance territoriale internationale n’est déduite.';

--
-- Name: COLUMN "V_OffreArticleLocalisation"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticleLocalisation"."ID_Article" IS 'Offre publiée dont l’entreprise porte la localisation. Le retrait de publication retire immédiatement cette projection.';

--
-- Name: COLUMN "V_OffreArticleLocalisation".label; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".label IS 'Libellé déclaré le plus précis : niveau 5, sinon 4, sinon 3, sinon adresse détaillée. Aucune localisation automatique.';

--
-- Name: COLUMN "V_OffreArticleLocalisation".address; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".address IS 'Adresse détaillée volontairement enregistrée sur ce point professionnel, sans coordonnée personnelle de l’auteur.';

--
-- Name: COLUMN "V_OffreArticleLocalisation".zone; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".zone IS 'Nom du niveau 3 explicitement rattaché au point ; aucune parenté non renseignée n’est inventée.';

--
-- Name: COLUMN "V_OffreArticleLocalisation".area; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".area IS 'Nom du niveau 4 explicitement rattaché au point ; aucune parenté non renseignée n’est inventée.';

--
-- Name: COLUMN "V_OffreArticleLocalisation".site; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."V_OffreArticleLocalisation".site IS 'Nom du niveau 5 explicitement rattaché au point, sans garantie de disponibilité de l’article sur ce site.';
