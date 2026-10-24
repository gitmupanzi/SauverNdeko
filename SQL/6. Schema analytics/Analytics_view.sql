-- Extrait canonique du catalogue installé le 24/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
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
